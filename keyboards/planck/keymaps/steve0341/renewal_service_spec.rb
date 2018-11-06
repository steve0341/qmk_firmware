require 'rails_helper'

RSpec.describe RenewalService, type: :class do

  subject { RenewalService.new }
  let(:matter_client) { MatterService.new(token: get_valid_token[:token]) }

  let(:valid_renewals) {
    [
      {
        "next_renewal_date"=>"2016-12-31",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"USD"},
        "grace_period_end_date"=>"2017-06-30",
        "next_grace_period_fee"=>{"price"=>"55.0", "currency"=>"USD"},
        "next_claim_fee"=>{"price"=>"35.0", "currency"=>"USD"}
      },
      {
        "next_renewal_date"=>"2019-01-01",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"HKD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"HKD"},
        "grace_period_end_date"=>"2017-06-30",
        "next_grace_period_fee"=>{"price"=>"60.0", "currency"=>"HKD"},
        "next_claim_fee"=>{"price"=>"25.0", "currency"=>"HKD"}
      },
      {
        "next_renewal_date"=>"2019-02-02",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"USD"},
        "grace_period_end_date"=>"2017-06-30",
        "next_grace_period_fee"=>{"price"=>"15.0", "currency"=>"USD"},
        "next_claim_fee"=>{"price"=>"75.0", "currency"=>"USD"}
      }
    ]
  }

  let(:renewals_with_garbage_data) {
    [
      "This API is in a pre-launch state, and will go through significant changes.",
      {
        "next_renewal_date"=>"2019-01-01",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"USD"},
        "grace_period_end_date"=>"2019-05-01"
      },
      {
        "next_renewal_date"=>"2019-02-02",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"USD"},
        "grace_period_end_date"=>"2019-05-02"
      },
      {
        "next_renewal_date"=>"2019-03-03",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee",
        "next_agent_fee"=>{"price"=>"95.0", "currency"=>"USD"},
        "grace_period_end_date"=>"2019-05-03"
      },
      {"debug"=>"No next Renewal Date", "debug_code"=>"[nil]"}
    ]
  }

  before do
    create(:currency, name: "USD", to_usd: 0.5)
    create(:currency, name: "HKD", to_usd: 2)
  end

  it "retrieves renewals by matter successfully" do
    matterUcid = "TW-103134966-A"
    matters = matter_client.getMattersByUcid(matterUcid)
    resp = subject.getRenewalsByMatters(matters)
  end

  it "remove_garbage removes unnecessary data in response for renewals" do
    renewals = subject.remove_garbage(renewals_with_garbage_data)
    garbage_data_one = "This API is in a pre-launch state"
    has_debug_garbage = renewals.any? { |r| r.keys.include?("debug") if r.is_a? Hash }
    expect(renewals.size).to be 3
    expect(has_debug_garbage).to be_falsey
  end

  it "build_renewals builds renewals correctly" do
    matter = Matter.new(matterUcid: "TW-103134966-A")
    renewals = []
    renewals = subject.build_renewals(renewals, valid_renewals, matter)
    expect(renewals.size).to be 3
    validate_built_renewals(renewals, valid_renewals, matter)
  end

  it "build_renewals builds renewals with missing fees and currencies" do
    matter = Matter.new(matterUcid: "TW-103134966-A")
    renewals = []

    limited_fees = [
      {
        "next_renewal_date"=>"2016-12-31",
        "renewal_sequence"=>2,
        "next_renewal_fee"=>{"price"=>"85.0", "currency"=>"USD"},
        "next_renewal_description"=>"2nd Annuity - Official Fee"
      }
    ]

    renewals = subject.build_renewals(renewals, limited_fees, matter)
    expect(renewals.size).to be 1
    validate_built_renewals(renewals, limited_fees, matter)
  end

  describe "#update_renewal_instructions" do
    before do
      create(:portfolio)
      create_list(:renewal, 2, portfolio_id: Portfolio.first.id, current_instruction: "undecided", confidence: nil)
    end

    it "updates renewal's instruction(s) successfully" do
      instruction = "pay"
      instructions = [
        { id: Renewal.first.id, current_instruction: instruction, confidence: :low},
        { id: Renewal.second.id, current_instruction: instruction, confidence: :high}
      ]
      renewals = subject.update_renewal_instructions(instructions)
      expect(renewals.pluck(:current_instruction)).to match [instruction, instruction]
      expect(renewals.pluck(:confidence)).to match ["low", "high"]
    end

    it "raise exception on invalid instruction" do
      renewal = Renewal.first
      instructions = [{ id: renewal.id, current_instruction: "abc" }]
      expect { subject.update_renewal_instructions(instructions)}.to raise_error RenewalExceptions::InvalidInstructionDetected
    end

    it "raise exception on invalid confidence level" do
      renewal = Renewal.first
      instructions = [{ id: renewal.id, confidence: "xyz" }]
      expect { subject.update_renewal_instructions(instructions)}.to raise_error RenewalExceptions::InvalidConfidenceDetected
    end

    it "Empty instructions return empty renewals" do
      instructions = {}
      renewals = subject.update_renewal_instructions(instructions)
      expect(renewals).to be_empty
    end
  end

  describe "#verify_portfolio_access_for_instructions" do
    before do
      create(:portfolio)
      create_list(:renewal, 2, portfolio_id: Portfolio.first.id, current_instruction: "undecided")
    end

    let(:user) { { user_id: "1" } }

    it "raise NoIdsFound exception for no ids in instructions" do
      instructions = [{}]
      expect { subject.verify_portfolio_access_for_instructions(user, instructions) }.to raise_error RenewalExceptions::NoIdsFound
    end

    it "raise NoIdsFound exception for no ids in instructions" do
      allow_any_instance_of(PortfolioPolicy).to receive(:can_access_portfolio?).and_return(false)
      instructions = [{ id: Renewal.first.id }]
      expect { subject.verify_portfolio_access_for_instructions(user, instructions) }.to raise_error RenewalExceptions::NoPortfolioAccessForRenewal
    end

    it "raise NoRenewalsFound when no renewals were found for ids" do
      invalid_renewal_id = 999
      instructions = [{ id: invalid_renewal_id }]
      expect { subject.verify_portfolio_access_for_instructions(user, instructions) }.to raise_error RenewalExceptions::NoRenewalsFound
    end
  end

  describe "#get_bhip_price_by_renewal" do

    it "returns correct bhip_price relating to country of US" do
      create(:portfolio, id: 1)
      create(:renewal, id: 2, portfolio_id: 1)
      create(:renewal_price, renewal_id: 2)

      portfolio = Portfolio.find 1
      renewal = portfolio.renewals.first
      renewal.country = "US"
      renewal.save!
      portfolio.create_bhip_price(us_price: 10, fn_price: 20)
      bhip_price = RenewalService.get_bhip_price_by_renewal(portfolio.renewals.first)
      expect(bhip_price).to_not be_nil
      expect(bhip_price.to_f).to eq 10
    end

    it "returns correct bhip_price to a foreign country" do
      create(:portfolio, id: 1)
      create(:renewal, id: 2, portfolio_id: 1)
      create(:renewal_price, renewal_id: 2)

      portfolio = Portfolio.find 1
      renewal = portfolio.renewals.first
      if renewal.country.downcase == "us"
        renewal.country = "Foreign Country"
        renewal.save!
      end
      portfolio.create_bhip_price(us_price: 10, fn_price: 20)
      bhip_price = RenewalService.get_bhip_price_by_renewal(portfolio.renewals.first)
      expect(bhip_price).to_not be_nil
      expect(bhip_price.to_f).to eq 20
    end

    it "return client bhip price" do
      client_id = 1
      portfolio_id = 2
      renewal_id = 3

      create(:client, id: client_id)
      create(:portfolio, id: portfolio_id, client_id: client_id)
      create(:bhip_price, id: 3, cost_type: 'Client', cost_id: client_id, us_price: 500)
      create(:renewal, id: renewal_id, portfolio_id: portfolio_id, country: 'US')

      bhip_fee = RenewalService.get_bhip_price_by_renewal(Renewal.find(renewal_id))
      expect(bhip_fee).to eq 500
    end

    it "return portfolio bhip price" do
      client_id = 1
      portfolio_id = 2
      renewal_id = 3

      create(:client, id: client_id)
      create(:portfolio, id: portfolio_id, client_id: client_id)
      create(:bhip_price, id: 3, cost_type: 'Portfolio', cost_id: portfolio_id, us_price: 1000)
      create(:renewal, id: renewal_id, portfolio_id: portfolio_id, country: 'US')

      bhip_fee = RenewalService.get_bhip_price_by_renewal(Renewal.find(renewal_id))
      expect(bhip_fee).to eq 1000
    end

    it "return zero when no bhip price exists" do
      client_id = 1
      portfolio_id = 2
      renewal_id = 3

      create(:client, id: client_id)
      create(:portfolio, id: portfolio_id, client_id: client_id)
      create(:renewal, id: renewal_id, portfolio_id: portfolio_id, country: 'US')

      bhip_fee = RenewalService.get_bhip_price_by_renewal(Renewal.find(renewal_id))
      expect(bhip_fee).to eq 0
    end

    after do
      Client.destroy_all
    end
  end

  describe "#validate_instruction(s)" do
    let(:valid_instructions) { [{current_instruction: "undecided"}] }
    let(:valid_instruction) { "undecided" }
    let(:invalid_instructions) { [{ current_instruction: "invalid" }] }
    let(:invalid_instruction) { "invalid" }

    it "raises error on invalid instructions" do
      expect{ subject.validate_instructions(invalid_instructions) }.to raise_error RenewalExceptions::InvalidInstructionDetected
    end

    it "does not raise error for instructions" do
      expect{ subject.validate_instructions(valid_instructions)}.to_not raise_error
    end

    it "raises error on invalid instructions" do
      expect{ subject.validate_instruction(invalid_instruction) }.to raise_error RenewalExceptions::InvalidInstructionDetected
    end

    it "does not raise error for instructions" do
      expect{ subject.validate_instruction(valid_instruction) }.to_not raise_error
    end
  end

  describe "#validate_future_date" do
    let(:valid_future_date) { DateTime.now + 1.day }
    let(:invalid_future_date) { DateTime.now - 1.day }

    it "raise error if date is not a future date" do
      expect { subject.validate_future_date(invalid_future_date) }.to raise_error RenewalExceptions::NoFutureDate
    end

    it "do not raise error on valid future date" do
      expect { subject.validate_future_date(valid_future_date) }.to_not raise_error
    end
  end

  def validate_built_renewals(renewals, json, matter)
    renewals.each_with_index do |renewal, index|
      expect(renewal.country).to eq matter.applicationCountry
      expect(renewal.serial_no).to eq matter.serialNumber
      expect(renewal.ucid).to eq matter.matterUcid

      expect(renewal.description).to eq json[index]["next_renewal_description"].to_s
      expect(renewal.due_date.to_s).to eq json[index]["next_renewal_date"].to_s
      expect(renewal.grace_date.to_s).to eq json[index]["grace_period_end_date"].to_s

      expect(renewal.renewal_price.calculated_due_price).to eq calculate_exchange(json[index].dig("next_renewal_fee", "price").to_i, get_exchange_rate(json[index].dig("next_renewal_fee", "currency")))
      expect(renewal.renewal_price.calculated_agent_price).to eq calculate_exchange(json[index].dig("next_agent_fee", "price").to_i, get_exchange_rate(json[index].dig("next_agent_fee", "currency")))
      expect(renewal.renewal_price.calculated_grace_price).to eq calculate_exchange(json[index].dig("next_grace_period_fee", "price").to_i, get_exchange_rate(json[index].dig("next_grace_period_fee", "currency")))
      expect(renewal.renewal_price.calculated_claim_price).to eq calculate_exchange(json[index].dig("next_claim_fee", "price").to_i, get_exchange_rate(json[index].dig("next_claim_fee", "currency")))
    end
  end

  describe "#calculate_exchange" do
    before do
      Currency.destroy_all
    end

    it "calculates correct fee" do
      create(:currency, name: "USD", to_usd: 0.5)
      currency = "USD"
      fee = 10
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 5
    end

    it "on empty currencies" do
      currency = "USD"
      fee = 10
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 0
    end

    it "no matching currency" do
      create(:currency, name: "HKD", to_usd: 10)
      currency = "USD"
      fee = 10
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 0
    end

    it "fee is zero" do
      create(:currency, name: "USD", to_usd: 0.5)
      currency = "USD"
      fee = 0
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 0
    end

    it "fee is nil" do
      create(:currency, name: "USD", to_usd: 0.5)
      currency = "USD"
      fee = nil
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 0
    end

    it "ensure cents are returned" do
      create(:currency, name: "USD", to_usd: 0.5)
      currency = "USD"
      fee = 10.50
      price = subject.calculate_exchange(fee, currency)
      expect(price).to eq 5.25
    end
  end

  describe "#default_currency" do
    it "returns original currency" do
      currency = "CAD"
      result = subject.currency_default(currency)
      expect(result).to eq currency
    end

    it "returns USD as currency on NULL currency" do
      currency = "NULL"
      result = subject.currency_default(currency)
      expect(result).to eq "USD"
    end
  end

  describe "#update_renewal_prices" do
    before do
      Currency.delete_all
      countries = ["USD", "JPY"]
      # COUNTRY LIST
      create(:currency, name: countries.first, to_usd: 1)
      # CURRENCIES
      create(:currency, name: countries.second, to_usd: 1000)
      # RENEWAL PRICES
      create(:renewal_price, id: 1,
        due_currency: countries.first,
        grace_currency: countries.first,
        claim_currency: countries.first,
        agent_currency: countries.first,
        due_price: 1,
        grace_price: 3,
        claim_price: 5,
        agent_price: 7
      )
      create(:renewal_price, id: 2,
        due_currency: countries.second,
        grace_currency: countries.second,
        claim_currency: countries.second,
        agent_currency: countries.second,
        due_price: 2,
        grace_price: 4,
        claim_price: 6,
        agent_price: 8
      )
    end

    it "sets/updates prices for renewal" do
      RenewalPrice.all.each do |price|
        subject.update_renewal_prices(price)
      end

      prices_one = RenewalPrice.find 1
      expect(prices_one.calculated_due_price.to_f).to eq 1
      expect(prices_one.calculated_grace_price.to_f).to eq 3
      expect(prices_one.calculated_claim_price.to_f).to eq 5
      expect(prices_one.calculated_agent_price.to_f).to eq 7

      prices_two = RenewalPrice.find 2
      expect(prices_two.calculated_due_price.to_f).to eq 2000
      expect(prices_two.calculated_grace_price.to_f).to eq 4000
      expect(prices_two.calculated_claim_price.to_f).to eq 6000
      expect(prices_two.calculated_agent_price.to_f).to eq 8000
    end
  end

  describe "#get_pay_instruction_total" do

    before do
      Client.destroy_all
      create(:client, id: 1)
      create(:portfolio, id: 2, client_id: 1)
      create(:bhip_price, id: 3, cost_type: 'Portfolio', cost_id: 2, us_price: 10, fn_price: 50)

      # RENEWALS
      create(:renewal, id: 4, portfolio_id: 2, current_instruction: 'undecided', country: 'US')
      create(:renewal, id: 5, portfolio_id: 2, current_instruction: 'pay', country: 'US')
      create(:renewal, id: 6, portfolio_id: 2, current_instruction: 'pay', country: 'GB')

      # RENEWAL PRICES
      create(:renewal_price,
        calculated_agent_price: 2,
        calculated_claim_price: 4,
        calculated_due_price: 6,
        calculated_grace_price: 8,
        renewal_id: 4
      )

      create(:renewal_price,
        calculated_agent_price: 2,
        calculated_claim_price: 4,
        calculated_due_price: 6,
        calculated_grace_price: 8,
        renewal_id: 5
      )

      create(:renewal_price,
        calculated_agent_price: 2,
        calculated_claim_price: 4,
        calculated_due_price: 6,
        calculated_grace_price: 8,
        renewal_id: 6
      )
    end

    it "retrieve total cost of pay instructed renewals" do
      pay_instruction_total = RenewalService.get_pay_instruction_total(Renewal.all)
      expect(pay_instruction_total).to eq 100
    end

    it "total is zero for undecided instructions" do
      Renewal.all.each { |renewal| renewal.update!(current_instruction: 'undecided') }
      pay_instruction_total = RenewalService.get_pay_instruction_total(Renewal.all)
      expect(pay_instruction_total).to eq 0
    end
  end

  def calculate_exchange(fee, rate)
    return rate * fee if fee && rate
  end

  def get_exchange_rate(country_code)
    currency = Currency.find_by(name: country_code)
    return currency ? currency.to_usd : 0.0
  end

  after do
    Client.destroy_all
    Currency.destroy_all
  end
end
