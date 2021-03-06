require 'google/cloud/firestore'
require_relative '../model/store'
require_relative '../model/transaction'
require_relative '../util'

# Module for Firebase Firestore Service methods
class FirestoreService
  include Util

  # Names of our firebase data structure (client facing)
  STORES_COL_NAME = 'stores'.freeze
  VENDORS_COL_NAME = 'vendors'.freeze
  CUSTOMERS_COL_NAME = 'customers'.freeze
  TXN_COL_NAME = 'transactions'.freeze
  VENDOR_STORES_PROP = 'stores'.freeze
  STORE_BACKEND_COL_NAME = 'backend'.freeze
  STORE_BACKEND_STRIPE_DOC_NAME = 'stripe'.freeze

  # Names of our firebase data structure for secrets
  SECRETS_COL_NAME = 'secrets'.freeze
  JWT_KEY_DOC = 'JWT_KEY'.freeze
  STRIPE_KEY_DOC = 'STRIPE_API_SECRET'.freeze
  MAILGUN_KEY_DOC = 'MAILGUN'.freeze

  # Constructor
  def initialize(firestore)
    @firestore = firestore
  end

  # Saves a store to firestore and returns the firestore ID for the store
  # Will also add the store to the "stores" field of the owner vendor
  #
  # @param [Store] store to save
  # @return [String] firestore id if successfully saved
  def save_store(store, vendor_id)
    # Reference to the stores collection
    stores_ref = @firestore.col STORES_COL_NAME
    basic_store_data = {
      name: store.name,
      default_currency: store.default_currency,
      parent_vendor_id: vendor_id
    }
    log_info "Saving store: #{store.name}"

    added_store_ref = stores_ref.doc
    added_store_ref.set basic_store_data
    log_info "Successfully saved store #{store.name}
          with ID: #{added_store_ref.document_id}."

    # Now save all the stripe information
    store_stripe_ref = added_store_ref.col(STORE_BACKEND_COL_NAME)
                                      .doc(STORE_BACKEND_STRIPE_DOC_NAME)
    stripe_data = {
      stripe_publishable_key: store.stripe_publishable_key,
      stripe_user_id: store.stripe_user_id,
      stripe_refresh_token: store.stripe_refresh_token,
      stripe_access_token: store.stripe_access_token,
      txn_fee_base: store.txn_fee_base,
      txn_fee_percent: store.txn_fee_percent
    }
    store_stripe_ref.set stripe_data
    log_info 'Successfully saved store Stripe data'

    store_firebase_id = added_store_ref.document_id

    # Now save the store ID to the vendor
    # TODO we should use batch writes for this
    # TODO this will overwrite the existing array - when we support multiple stores, deal with this.
    @firestore.col(VENDORS_COL_NAME)
              .doc(vendor_id)
              .update(
                Hash[VENDOR_STORES_PROP, [store_firebase_id]]
              )

    log_info 'Successfully updated vendor with store ID'

    # Return the firebase ID
    store_firebase_id
  end

  # Loads and returns a store from firestore with the given ID
  # Returns nil if the store does not exist
  #
  # @param [String] id - firestore id for the store
  # @return [Store] - a store object or nil if not found
  def get_store(id)
    store_id = id

    # First get the main document - if this exists then the store exists
    store_main_doc_ref = @firestore.col(STORES_COL_NAME)
                                   .doc(store_id)
    store_main_doc = store_main_doc_ref.get
    if store_main_doc.exists?
      store_name = store_main_doc.data[:name]
      default_currency = store_main_doc.data[:default_currency]
    else
      log_info "Store with id #{store_id} does not exist"
      return nil
    end

    # Now get the stripe information
    store_str_doc_ref = store_main_doc_ref.col(STORE_BACKEND_COL_NAME)
                                          .doc(STORE_BACKEND_STRIPE_DOC_NAME)
    store_str_doc = store_str_doc_ref.get
    if store_str_doc.exists?
      stripe_data = store_str_doc.data
      store_str_pub_key = stripe_data[:stripe_publishable_key]
      store_str_user_id = stripe_data[:stripe_user_id]
      store_str_ref_tok = stripe_data[:stripe_refresh_token]
      store_str_acc_tok = stripe_data[:stripe_access_token]
      txn_fee_base = stripe_data[:txn_fee_base]
      txn_fee_percent = stripe_data[:txn_fee_percent]
    else
      log_info "Store with id #{store_id} does not have Stripe info"
      return nil
    end

    # return new store object
    Store.new(store_id, store_name, store_str_pub_key,
              store_str_user_id, store_str_ref_tok, store_str_acc_tok,
              txn_fee_base, txn_fee_percent, default_currency)
  end

  # Returns a transaction from firestore given the transaction ID
  #
  # @param id The transaction ID in firestore - same as stripe ID
  # @return Transaction object
  def get_txn(id)
    txn_id = id

    # Get the transaction and check that it exists
    txn_doc = @firestore.col(TXN_COL_NAME).doc(txn_id).get
    if txn_doc.exists?
      # Construct the transaction object that we need
      txn_data = txn_doc.data

      # Deconstruct main transaction object
      total_amt = txn_data[:amount]
      tax_amt = txn_data[:taxes]
      date = txn_data[:date] # Ruby date object
      store_id = txn_data[:store_id]
      items_from_firestore = txn_data[:items]

      # Deconstruct each item
      items = []
      items_from_firestore.each do |firestore_item|

        item_name = firestore_item[:name]
        item_cost = firestore_item[:cost]
        item_qty = firestore_item[:quantity]
        item_price_unit = firestore_item[:price_unit]
        # Add to array
        items.push Transaction::Item.new(item_name, item_cost,
                                         item_price_unit, item_qty)
      end

      Transaction.new(txn_id, total_amt, tax_amt,
                      date, store_id, items)
    else
      log_info "Transaction with id #{txn_id} was not found"
      nil
    end
  end

  # Determines if the given user ID is a valid entry within our database
  # @param user_id The firebase ID of either a customer or a vendor
  def valid_user?(user_id)

    # Customers use endpoints more often - so check this first
    customer_doc = @firestore.col(CUSTOMERS_COL_NAME)
                             .doc(user_id)
                             .get
    return true if customer_doc.exists?

    # Try searching in vendors
    vendor_doc = @firestore.col(VENDORS_COL_NAME)
                           .doc(user_id)
                           .get
    return true if vendor_doc.exists?

    false
  end

  # Retrieves the given secret from firebase
  #
  # @param secret_name The constant (defined in this class) for the secret
  def get_secret(secret_name)

    secret_doc = @firestore.col(SECRETS_COL_NAME)
                           .doc(secret_name)
                           .get

    # Return the secret if we can find it
    return secret_doc.data[:key] if secret_doc.exists?

    # Else return nil
    log_info "Could not find secret #{secret_name} - document does not exist"
    nil
  end

end
