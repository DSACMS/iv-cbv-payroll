#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative "../translation_diff_generator"

namespace :translations do
  desc "Generate CSV file with translation differences since branch creation"
  task generate: :environment do
    TranslationDiffGenerator.new.generate_csv
  end
end
