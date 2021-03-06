require_relative '../service/firestore_service'
require_relative 'endpoint_helper'
require_relative '../util'

module SecurityEndpoints
  include EndpointHelper
  include Util

  # Returns a JWT token with 60 second expiry time
  # If & only if the user is a valid customer or a valid vendor
  def create_refresh_token(json_input, firestore_service, jwt_secret)
    # Check that the user ID is valid
    input_user_id = json_input['user_id']
    # If valid, return a new JWT, else deny
    if firestore_service.valid_user? input_user_id
      # Return the new JWT
      new_token = create_jwt input_user_id, Time.now.to_i + 60, jwt_secret
      { token: new_token }.to_json
    else
      return_error 401, 'Access Denied - Invalid User ID'
    end
  end
end
