class CbvClient < ApplicationRecord
  has_one :cbv_flow
  has_one :cbv_flow_invitation
end
