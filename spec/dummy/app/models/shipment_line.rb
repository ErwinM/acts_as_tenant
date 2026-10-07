class ShipmentLine < ActiveRecord::Base
  acts_as_tenant :account
  belongs_to :shipment, foreign_key: [:shipment_number, :region], primary_key: [:number, :region], optional: true
end
