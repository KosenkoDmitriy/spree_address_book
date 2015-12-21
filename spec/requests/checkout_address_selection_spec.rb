require 'spec_helper'

describe "Address selection during checkout", js: true do
  include_context "store products"

  let(:state) {  Spree::State.all.first || FactoryGirl.create(:state) }

  describe "as guest user" do
    include_context "checkout with product"
    before(:each) do
      click_button "Checkout"
      fill_in "order_email", with: "guest@example.com"
      click_button "Continue"
    end

    it "should only see billing address form", js: true do
      within("#billing") do
        should_have_address_fields
        expect(page).not_to have_selector(".select_address")
      end
    end

    it "should only see shipping address form", js: true do
      within("#shipping") do
        should_have_address_fields
        expect(page).not_to have_selector(".select_address")
      end
    end
  end

  describe "as authenticated user with saved addresses", js: true do
    include_context "checkout with product"
    # include_context "user with address"
    before(:each) do
      @user = FactoryGirl.create(:user)
      @user.addresses << FactoryGirl.create(:address, :address1 => Faker::Address.street_address, :state => state, :alternative_phone => nil)
      @user.save
    end

    let(:billing) { FactoryGirl.build(:address, :state => state) }
    let(:shipping) do
      FactoryGirl.build(:address, :address1 => Faker::Address.street_address, :state => state)
    end
    let(:user) { @user }

    before(:each) {
      sign_in!(user)
      wait_for_ajax
      visit "/cart"
      click_button "Checkout"
    }
  
    it "should not see billing or shipping address form" do
      expect(find("#billing .inner")).not_to be_visible
      expect(find("#shipping .inner")).not_to be_visible
    end
  
    it "should list saved addresses for billing and shipping" do
      within("#billing .select_address") do
        user.addresses.each do |a|
          expect(page).to have_field("order_bill_address_attributes_address#{a.id}")
        end
      end
      within("#shipping .select_address") do
        user.addresses.each do |a|
          expect(page).to have_field("order_ship_address_id_#{a.id}")
        end
      end
    end
      
    it "should save 2 addresses for user if they are different", js: true do
      expect do
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(billing)
        end
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(2)
    end
  
    it "should save 1 address for user if they are the same" do
      expect do
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(billing)
        end
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(billing, :ship)
        end
        complete_checkout
      end.to change { user.addresses.count }.by(1)
    end
      
    describe "when invalid address is entered", js: true do
      let(:address) do
        FactoryGirl.build(:address, :firstname => nil, :state => state)
      end
      
      # TODO the JS error reporting isn't working with our current iteration
      # this is what this piece of code ('field is required') tests
      it "should show address form with error" do
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(address)
        end
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(address, :ship)
        end
        click_button "Save and Continue"
        within("#bfirstname") do
          expect(page).to have_content("field is required")
        end
        within("#sfirstname") do
          expect(page).to have_content("field is required")
        end
      end
    end
  
    describe "entering 2 new addresses", js: true do
      it "should assign 2 new addresses to order" do
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(billing)
        end
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(billing))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(shipping))
        end
      end
    end
  
    describe "using saved address for bill and new ship address", js: true do
      let(:shipping) do
        FactoryGirl.build(:address, :address1 => Faker::Address.street_address,
          :state => state)
      end
  
      it "should save 1 new address for user" do
        expect do
          address = user.addresses.first
          choose "order_bill_address_attributes_address#{address.id}"
          within("#shipping") do
            page.uncheck 'order_use_billing'
            choose I18n.t('address_book.other_address')
            fill_in_address(shipping, :ship)
          end
          complete_checkout
        end.to change{ user.addresses.count }.by(1)
      end
  
      it "should assign addresses to orders" do
        address = user.addresses.first
        choose "order_bill_address_attributes_address#{address.id}"
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(address))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(shipping))
        end
      end
  
      it "should see form when new shipping address invalid" do
        address = user.addresses.first
        shipping = FactoryGirl.build(:address, :address1 => nil, :state => state)
        choose "order_bill_address_attributes_address#{address.id}"
        within("#shipping") do
          page.uncheck 'order_use_billing'
          choose I18n.t('address_book.other_address')
          fill_in_address(shipping, :ship)
        end
        click_button "Save and Continue"
        within("#saddress1") do
          expect(page).to have_content("field is required")
        end
        within("#billing") do
          expect(find("#order_bill_address_attributes_address#{address.id}")).to be_checked
        end
      end
    end
  
    describe "using saved address for billing and shipping", js: true do
      it "should addresses to order" do
        address = user.addresses.first
        choose "order_bill_address_attributes_address#{address.id}"
        check "Use Billing Address"
        complete_checkout
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(address))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(address))
        end
      end
  
      it "should not add addresses to user" do
        expect do
          address = user.addresses.first
          choose "order_bill_address_attributes_address#{address.id}"
          check "Use Billing Address"
          complete_checkout
        end.to_not change{ user.addresses.count }
      end
    end
  
    describe "using saved address for ship and new bill address", js: true do
      let(:billing) do
        FactoryGirl.build(:address, :address1 => Faker::Address.street_address, :state => state, :zipcode => '90210')
      end
  
      it "should save 1 new address for user" do
        expect do
          address = user.addresses.first
          page.uncheck 'order_use_billing'
          choose "order_ship_address_id_#{address.id}"
          within("#billing") do
            choose I18n.t('address_book.other_address')
            fill_in_address(billing)
          end
          complete_checkout
        end.to change{ user.addresses.count }.by(1)
      end
  
      it "should assign addresses to orders" do
        address = user.addresses.first
        page.uncheck 'order_use_billing'
        choose "order_ship_address_id_#{address.id}"
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(billing)
        end
        complete_checkout
        expect(page).to have_content("processed successfully")
        within("#order > div.row.steps-data > div:nth-child(1)") do
          expect(page).to have_content("Billing Address")
          expect(page).to have_content(expected_address_format(billing))
        end
        within("#order > div.row.steps-data > div:nth-child(2)") do
          expect(page).to have_content("Shipping Address")
          expect(page).to have_content(expected_address_format(address))
        end
      end
    
      # TODO not passing because inline JS validation not working
      it "should see form when new billing address invalid" do
        address = user.addresses.first
        billing = FactoryGirl.build(:address, :address1 => nil, :state => state)
        page.uncheck 'order_use_billing'
        choose "order_ship_address_id_#{address.id}"
        within("#billing") do
          choose I18n.t('address_book.other_address')
          fill_in_address(billing)
        end

        click_button "Save and Continue"
        within("#baddress1") do
          expect(page).to have_content("field is required")
        end
        within("#shipping") do
          expect(find("#order_ship_address_id_#{address.id}")).to be_checked
        end
      end
    end
  
    describe "entering address that is already saved", js: true do
      it "should not save address for user" do
        expect do
          address = user.addresses.first
          page.uncheck 'order_use_billing'
          choose "order_ship_address_id_#{address.id}"
          within("#billing") do
            choose I18n.t('address_book.other_address')
            fill_in_address(address)
          end
          complete_checkout
        end.to_not change { user.addresses.count }
      end
    end
  end
end
