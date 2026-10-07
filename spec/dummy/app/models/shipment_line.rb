class ShipmentLine < ActiveRecord::Base
  acts_as_tenant :account

  # Rails 7.2 added composite foreign_key/primary_key options, Rails 7.1 only supports query_constraints
  if ActiveRecord.version >= Gem::Version.new("7.2")
    belongs_to :shipment, foreign_key: [:shipment_number, :region], primary_key: [:number, :region], optional: true
    belongs_to :parcel, foreign_key: [:account_id, :parcel_number], primary_key: [:account_id, :number], optional: true
  elsif ActiveRecord.version >= Gem::Version.new("7.1")
    belongs_to :shipment, query_constraints: [:shipment_number, :region], optional: true
  end
end
