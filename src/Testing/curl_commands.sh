#!/usr/bin/env bash

# make sure to have jq installed for pretty json
echo "Test connection "
curl -X GET http://localhost:4567/
echo "Create Ephemeral Key"
curl -d '{"customer_id":"cus_Eic7D12EByBANL","stripe_version":"2019-03-14"}' -H "Content-Type: application/json" -X POST http:/localhost:4567/customers/create-ephemeral-key | jq
echo "Create Customer"
curl -i -X GET http://34.219.126.153:4567/make_customer
echo "Charge "
curl -d '{"amount":"1000", "customer_id":"cus_Eic7D12EByBANL", "CONNECTED_STRIPE_ACCOUNT_ID":"acct_1EALLCF8Tv70HUia"}' -H "Content-Type: application/json" -X POST http://localhost:4567/charge | jq
echo "Create standard account"
curl -d '{"account_auth_code":"ac_Eix70se8M3dejLmSxB2PMV3A7lQUjqg0"}' -H "Content-Type: application/json" -X POST http://localhost:4567/vendors/connect-standard-account






