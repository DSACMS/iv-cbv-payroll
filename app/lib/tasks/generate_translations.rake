#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative "../translation_diff_generator"

namespace :translations do
  desc "Generate CSV file with translation differences from main branch"
  task generate: :environment do
    TranslationDiffGenerator.new.generate_csv
  end
end
