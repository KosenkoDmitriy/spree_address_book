require 'spec_helper'

describe "User editing addresses for his account", js: true do
  include_context "user with address"

  before(:each) do
    visit spree.root_path
    click_link "Login"
    sign_in!(user)
    wait_for_ajax
    click_link('My Account')
  end

  it "should see list of addresses saved for account" do
    expect(page).to have_content("Addresses")
    if (user.addresses.count > 0)
      expect(page).to have_selector("table#user_addresses > tbody > tr", count: user.addresses.count)
    else
      expect(page).to have_content("No addresses on file")
    end
  end

  it "should be able to add address" do
    expect(find_link('Add new address').visible?).to eq true
  end

  it "should be able to edit address", js: true do
    page.evaluate_script('window.confirm = function() { return true; }')
    within("table#user_addresses tr:nth-child(1)") do
      click_link Spree.t(:edit)
    end

    expect(current_path).to eq spree.edit_address_path(address)

    new_street = Faker::Address.street_address
    fill_in :address_address1, with: new_street
    click_button "Update"

    expect(current_path).to eq spree.account_path
    expect(page).to have_content('Updated successfully')

    within("table#user_addresses tr:nth-child(1)") do
      expect(page).to have_content(new_street)
    end
  end

  it "should be able to remove address", js: true do
    # bypass confirm dialog
    page.evaluate_script('window.confirm = function() { return true; }')
    within("table#user_addresses tr:nth-child(1)") do
      click_link Spree.t(:remove)
    end

    expect(current_path).to eq spree.account_path

    # flash message
    expect(page).to have_content("removed")

    # header still exists for the area - even if it is blank
    expect(page).to have_content("Addresses")

    # table is not displayed unless addresses are available
    expect(page).to_not have_selector("#user_addresses")
  end
end
