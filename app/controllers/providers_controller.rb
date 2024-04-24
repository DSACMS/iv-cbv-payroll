class ProvidersController < ApplicationController
  ENDPOINT = 'https://sampleapps.argyle.com/employer-search/api/search?q=';

  def index
  end

  def search
    # sample endpoint — let's replace with a real sandbox
    # https://sampleapps.argyle.com/employer-search/api/search?q=nava
    # results = Net::HTTP.get(URI.parse("#{ENDPOINT}#{params.q}"))
  end

  def confirm
    @employer = employer_params[:employer]
    @payments = [
      { amount: 810, start: 'March 25', end: 'June 15', hours: 54, rate: 15  },
      { amount: 195, start: 'January 1', end: 'February 23', hours: 13, rate: 15  }
    ]
  end

  private

  def employer_params
    params.permit(:employer)
  end
end
