# frozen_string_literal: true

class ConfiguredAgencyConstraint
  def matches?(req)
    subdomain = extract_subdomain(req)
    subdomain.present? && configured_agency?(subdomain)
  end

  private

  # get the subdomain being requested
  def extract_subdomain(req)
    base = ENV["DOMAIN_NAME"].to_s
    host = req.host.to_s
    return nil if base.blank?
    return nil unless host.end_with?(base)
    return nil if host == base

    remainder = host.delete_suffix(".#{base}")
    labels = remainder.split(".").reject(&:empty?)
    labels.first # host
  end

  # determine if the subdomain represents a configured agency
  def configured_agency?(slug)
    cfg = Rails.application.config.client_agencies
    cfg.client_agency_ids.any? do |id|
      agency = cfg[id]
      agency.agency_domain.to_s == slug
    end
  end
end
