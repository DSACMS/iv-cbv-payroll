class Identity < ApplicationRecord
  include Redactable

  has_redactable_fields(
    first_name: :unique_string,
    last_name: :string,
    date_of_birth: :date
  )

  has_many :activity_flows, dependent: :destroy
end
