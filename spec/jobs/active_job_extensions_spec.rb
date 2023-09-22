require "spec_helper"

class ApplicationTestJob < ApplicationJob
  def perform(expected_tenant:)
    raise ApplicationTestJobTenantError unless ActsAsTenant.current_tenant == expected_tenant
    Project.all
  end
end

class ApplicationTestJobTenantError < StandardError; end

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
end
