require "spec_helper"

class ApplicationTestJob < ApplicationJob
  def perform(expected_tenant:)
    raise ApplicationTestJobTenantError unless ActsAsTenant.current_tenant == expected_tenant
    Project.all
  end
end

class ApplicationTestJobTenantError < StandardError; end

class DiscardingTestJob < ApplicationTestJob
  discard_on ActiveRecord::RecordNotFound
end

class CallbackTestJob < ApplicationTestJob
  cattr_accessor :tenant_in_callback
  before_perform { self.class.tenant_in_callback = ActsAsTenant.current_tenant }
end

RSpec.describe ApplicationTestJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { accounts(:foo) }

  describe "#perform_later" do
    context "when tenant is required" do
      before { allow(ActsAsTenant.configuration).to receive_messages(require_tenant: true) }

      it "raises ApplicationTestJobTenantError when expected_tenant does not match current_tenant" do
        ActsAsTenant.current_tenant = account
        expect { described_class.perform_later(expected_tenant: nil) }.to have_enqueued_job.on_queue("default")
        expect { perform_enqueued_jobs }.to raise_error(ApplicationTestJobTenantError)
      end

      it "when tenant is set, successfully queues and performs job" do
        ActsAsTenant.current_tenant = account
        expect { described_class.perform_later(expected_tenant: account) }.to have_enqueued_job.on_queue("default")
        expect { perform_enqueued_jobs }.not_to raise_error
      end

      it "when tenant is not set, successfully queues but fails to perform job" do
        ActsAsTenant.current_tenant = nil
        expect { described_class.perform_later(expected_tenant: nil) }.to have_enqueued_job.on_queue("default")
        expect { perform_enqueued_jobs }.to raise_error(ActsAsTenant::Errors::NoTenantSet)
      end
    end

    context "when tenant is not required" do
      before { allow(ActsAsTenant.configuration).to receive_messages(require_tenant: false) }
      it "when tenant is not set, queues and performs job" do
        ActsAsTenant.current_tenant = nil
        expect { described_class.perform_later(expected_tenant: nil) }.to have_enqueued_job.on_queue("default")
        expect { perform_enqueued_jobs }.not_to raise_error
      end
    end
  end

  describe "#perform_now" do
    let(:other_account) { accounts(:bar) }
    let(:job_data) { ActsAsTenant.with_tenant(account) { described_class.new(expected_tenant: account).serialize } }

    it "restores the tenant that was set before the job" do
      job = described_class.new
      job.deserialize(job_data)

      ActsAsTenant.with_tenant(other_account) do
        job.perform_now
        expect(ActsAsTenant.current_tenant).to eq(other_account)
      end
    end

    it "sets the tenant before the job's own callbacks run" do
      ActiveJob::Base.execute(ActsAsTenant.with_tenant(account) { CallbackTestJob.new(expected_tenant: account).serialize })
      expect(CallbackTestJob.tenant_in_callback).to eq(account)
    end

    it "does not run a job enqueued without a tenant under the tenant of the performing thread" do
      job = ActiveJob::Base.deserialize(described_class.new(expected_tenant: nil).serialize)

      ActsAsTenant.with_tenant(other_account) do
        expect { job.perform_now }.not_to raise_error
        expect(ActsAsTenant.current_tenant).to eq(other_account)
      end
    end

    context "when the tenant no longer exists" do
      # The job's arguments must not reference the tenant, or deserializing them would fail first.
      let(:job_data) { ActsAsTenant.with_tenant(account) { described_class.new(expected_tenant: nil).serialize } }

      before { job_data && account.destroy }

      it "deserializes the job without loading the tenant" do
        expect { described_class.new.deserialize(job_data) }.not_to raise_error
      end

      it "raises when the job is performed" do
        expect { ActiveJob::Base.execute(job_data) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "lets the job discard itself" do
        job_data["job_class"] = DiscardingTestJob.name
        expect { ActiveJob::Base.execute(job_data) }.not_to raise_error
      end
    end
  end

  describe "#serialize" do
    let(:other_account) { accounts(:bar) }

    it "serializes the tenant as a GlobalID string" do
      job_data = ActsAsTenant.with_tenant(account) { described_class.new(expected_tenant: account).serialize }
      expect(job_data["current_tenant"]).to eq(account.to_global_id.to_s)
    end

    it "keeps the tenant of a deserialized job when it is enqueued again" do
      job_data = ActsAsTenant.with_tenant(account) { described_class.new(expected_tenant: account).serialize }
      job = ActiveJob::Base.deserialize(job_data)

      ActsAsTenant.with_tenant(other_account) { job.enqueue }
      expect { perform_enqueued_jobs }.not_to raise_error
    end

    it "keeps a deserialized job without a tenant tenantless" do
      job = ActiveJob::Base.deserialize(described_class.new(expected_tenant: nil).serialize)

      ActsAsTenant.with_tenant(other_account) do
        expect(job.serialize["current_tenant"]).to be_nil
      end
    end
  end
end
