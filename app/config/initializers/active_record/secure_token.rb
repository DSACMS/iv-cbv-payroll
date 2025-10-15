# frozen_string_literal: true

module ActiveRecord
  module SecureToken
    # Lowering this minimum to support our 10 character tokenized links
    MINIMUM_TOKEN_LENGTH = 10
  end
end
