require 'rails_helper'

RSpec.describe ArgyleService, type: :service do
  include ArgyleApiHelper
  let(:service) { ArgyleService.new("sandbox", "FAKE_API_KEY") }
  let(:account_id) { 'abc123' }

  # describe '#fetch_items' do
  #  before do
  #    stub_request_items_response(BOB_USER_FOLDER)
  #  end

  #  it 'returns a non-empty response' do
  #    response = service.items('test')
  #    expect(response).not_to be_empty
  #  end
  # end

  describe '#fetch_paystubs' do
    context "for Bob, a Uber driver" do
      before do
        stub_request_paystubs_response("bob")
      end

      it 'returns an array of ResponseObjects::Paystub' do
        paystubs = service.fetch_paystubs(account: account_id)
        expect(paystubs.length).to eq(10)

        expect(paystubs[0]).to be_a(ResponseObjects::Paystub)
      end

      it 'returns with expected attributes without deductions or earning_categories' do
        paystubs = service.fetch_paystubs(account: account_id)

        expect(paystubs[0]).to have_attributes(
          account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
          gross_pay_amount: 34.56,
          net_pay_amount: 34.56,
          gross_pay_ytd: 547.68,
          pay_date: "2025-03-06",
          hours_by_earning_category: {},
          deductions: []
        )
        expect(paystubs[1]).to have_attributes(
          account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
          gross_pay_amount: 17.13,
          net_pay_amount: 17.13,
          gross_pay_ytd: 513.12,
          pay_date: "2025-02-27",
          hours_by_earning_category: {},
          deductions: []
        )
      end
    end

    context "for Joe, a W2 employee" do
      before do
        stub_request_paystubs_response("joe")
      end

      it 'returns an array of ResponseObjects::Paystub' do
        paystubs = service.fetch_paystubs(account: account_id)
        expect(paystubs.length).to eq(10)

        expect(paystubs[0]).to be_a(ResponseObjects::Paystub)
      end

      it 'returns with expected attributes including 1 earning category and multiple deductions' do
        paystubs = service.fetch_paystubs(account: account_id)

        expect(paystubs[0]).to have_attributes(
          account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
          gross_pay_amount: 5492.06,
          net_pay_amount: 3350.16,
          gross_pay_ytd: 16476.18,
          pay_date: "2025-03-03",
          hours_by_earning_category: {
            "base" => 92.9177
          },
          deductions: match_array([
            have_attributes(category: "401K", amount: 109.84),
            have_attributes(category: "Vision", amount: 219.68),
            have_attributes(category: "Dental", amount: 219.68)
          ])
        )
        expect(paystubs[1]).to have_attributes(
          account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
          gross_pay_amount: 5492.06,
          net_pay_amount: 3899.37,
          gross_pay_ytd: 10984.12,
          pay_date: "2025-02-03",
          hours_by_earning_category: {
            "base" => 174.4026
          },
          deductions: match_array([
            have_attributes(category: "Dental", amount: 164.76),
            have_attributes(category: "Roth", amount: 164.76),
            have_attributes(category: "Garnishment", amount: 164.76)
          ])
        )
      end
      it 'ignores earning categories that do not have hours (e.g. Bonus / Commission)' do
        paystubs = service.fetch_paystubs(account: account_id)

        expect(paystubs[3]).to have_attributes(
          account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
          gross_pay_amount: 5492.06,
          net_pay_amount: 4944.43,
          gross_pay_ytd: 74135.63,
          pay_date: "2024-12-02",
          hours_by_earning_category: {
            "base" => 139.5035
          },
          deductions: match_array([
            have_attributes(category: "Dental", amount: 164.76)
          ])
        )
      end

      it 'ignores earning categories that do not have hours (e.g. Bonus / Commission)' do
        paystubs = service.fetch_paystubs(account: account_id)

        expect(paystubs[4]).to have_attributes(
          account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
          gross_pay_amount: 9735.94,
          net_pay_amount: 9076.89,
          gross_pay_ytd: 68643.57,
          pay_date: "2024-11-01",
          hours_by_earning_category: {
            "base" => 76.0765,
            "overtime" => 39.191
          },
          deductions: match_array([
            have_attributes(category: "Garnishment", amount: 54.92)
          ])
        )
      end
    end
  end


  describe '#fetch_employment' do
      context "for Bob, a Uber driver" do
        before do
          stub_request_identities_response("bob")
        end

        it 'returns an array of ResponseObjects::Employment' do
          employments = service.fetch_employment(account: account_id)
          expect(employments.length).to eq(1)

          expect(employments[0]).to be_a(ResponseObjects::Employment)
        end

        it 'returns an array of ResponseObjects::Employment' do
          employments = service.fetch_employment(account: account_id)

          expect(employments[0]).to have_attributes(
            account_id: "019571bc-2f60-3955-d972-dbadfe0913a8",
            employer_name: "Lyft Driver",
            start_date: "2022-04-07",
            status: "employed",
          )
        end
      end
      context "for mapping employment status" do
          it 'employment status inactive => furloughed' do
            employment = ResponseObjects::Employment.from_argyle({
              "employment_status" => "inactive"
          })
            expect(employment).to have_attributes(
                status: "furloughed",
              )
          end
          it 'employment status active => employed' do
              employment = ResponseObjects::Employment.from_argyle({
                "employment_status" => "active"
            })
              expect(employment).to have_attributes(
                  status: "employed",
                )
            end
          it 'employment status terminated = terminated' do
                employment = ResponseObjects::Employment.from_argyle({
                  "employment_status" => "terminated"
              })
                expect(employment).to have_attributes(
                    status: "terminated",
                  )
              end
        end
    end
  describe '#fetch_income' do
      context "for Joe, a W2 employee" do
        before do
          stub_request_identities_response("joe")
        end

        it 'returns an array of ResponseObjects::Income' do
          incomes = service.fetch_income(account: account_id)
          expect(incomes.length).to eq(1)

          expect(incomes[0]).to be_a(ResponseObjects::Income)
        end

        it 'returns income object with expected attributes' do
          incomes = service.fetch_income(account: account_id)

          expect(incomes[0]).to have_attributes(
            account_id: "01956d62-18a0-090f-bc09-2ac44b7edf99",
            pay_frequency: "annual",
            compensation_amount: 65904.75,
            compensation_unit: "USD"
          )
        end
      end
    end
end
