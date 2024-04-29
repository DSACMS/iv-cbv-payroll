class ProvidersController < ApplicationController
  USER_TOKEN_ENDPOINT = "https://api-sandbox.argyle.com/v2/users"

  def index
    res = Net::HTTP.post(URI.parse(USER_TOKEN_ENDPOINT), "", { "Authorization" => "Basic #{ENV['ARGYLE_API_TOKEN']}" })

    @user_token = JSON.parse(res.body)["user_token"]
  end

  def search
  end

  def confirm
    @employer = employer_params[:employer]
    @payments = [
      { amount: 810, start: "March 25", end: "June 15", hours: 54, rate: 15  },
      { amount: 195, start: "January 1", end: "February 23", hours: 13, rate: 15  }
    ]
  end

  private

  def employer_params
    params.permit(:employer)
  end
end
