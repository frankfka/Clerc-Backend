# Ruby Backend for Clerc

Clerc is a checkout-as-a-service platform that I built and launched with a fellow Engineering Physics student. Clerc enables shoppers to shop with their phone at all participating retailers. Shoppers would scan items with our mobile app, and be able to checkout directly using their credit card or Apple/Android pay. This helps to eliminate unnecessary wait times at checkout queues.

An overview video can be found [here](https://www.youtube.com/watch?v=6UCnzB2EgSE) and a demo of the mobile app [here](https://www.youtube.com/watch?v=JkFDwkQ5GbA)

I was responsible for building a full-stack system that would allow shoppers to scan and pay for items with their mobile phone. On the front-end, this involved iOS and Android apps that made API calls to external services as well as our own backend. I also built a vendor dashboard in ReactJS for stores to manage their products.

The backend is responsible for processing payments and coordinating transaction information. The backend was written in Ruby and hosted on Google App Engine. We used Firebase for data storage as well as user management and authentication. To allow payments, we integrated with Stripe. 

### Setup 
1. Install Bundler (Dependency Manager)
```gem install bundler```
2. Install required dependencies with Bundler (in root directory)
```bundle install```
3. Download `Clerc-xxxxx.json` from Google Drive. This is required to authorize Firebase to access the Clerc project.
4. Place `Clerc-xxxxx.json` in any directory, then add it to your `PATH` with the following command: 
`export GOOGLE_APPLICATION_CREDENTIALS="[PATH_TO_JSON]/[FILE_NAME].json"`  
- Example command: `export GOOGLE_APPLICATION_CREDENTIALS="../Clerc-DEV.json"`
5. Make sure dev-specific code is uncommented (ex. dotenv stuff)
6. Run locally: `cd src` then `ruby server.rb`

### Endpoints

SECURED endpoints require a valid JWT token (See Security Endpoints)

##### General

1. ```GET /``` (Unsecured)
    - Test Endpoint
    - Expected Output: ```Connection Successful```

##### Customer Endpoints

1. ```POST /customers/create``` (Unsecured)
    - Creates empty, new customer
    - Input: None
    - Expected Output: 
    ```
    {"customer_id": "cus_EngWBBKckHWUT2"}
    ```

2. ```POST /customers/create-ephemeral-key``` (Secured)
    - Creates short-lived auth key for customer
    - Input (JSON Body): 
    ```
    {
      "customer_id": "cus_Eki4HaYdTlXbfc",
      "stripe_version": "2019-03-14",
      "token": "[YOUR_JWT_TOKEN]"
    }
    ```
    - Expected Output: Ephemeral key object from stripe
    ```
    {
        "id": "ephkey_1EQNhELrlHDdcgZ3oGK6X4fm",
        "object": "ephemeral_key",
        "associated_objects": [
            {
                "id": "cus_Eic7D12EByBANL",
                "type": "customer"
            }
        ],
        "created": 1555545704,
        "expires": 1555549304,
        "livemode": false,
        "secret": ""
    }
    ```

3. ```POST /charge``` (Secured)
    - Charges a customer with a vendor
    - Input (JSON Body): 
    ```
    {
      "customer_id": "cus_Eki4HaYdTlXbfc",
      "firebase_store_id": "fHwSHMW0kuBbNl6KQ4hG",
      "amount": 1000,
      "source": "src_1EHHPTLrlHDdcgZ3P8HWzrrI",
      "token": "[YOUR_JWT_TOKEN]"
    }
    ```
    - Expected Output: 
    ```
    {"charge_id":"ch_1EK5GMF8Tv70HUiaZtuylq6c"}
    ```
    
##### Vendor Endpoints

1. ```POST /vendors/connect-standard-account```
    - Initializes a new vendor & saves to firebase
    - Don't test this programmatically for now
    - Input (JSON Body): 
    ```
    {
      "account_auth_code": "[CODE_FROM_STRIPE]",
      "vendor_id": "[VALID VENDOR ID]",
      "store_name": "[ANY NAME]"
    }
    ```
    - Expected Output: 
    ```
    {"firebase_id":"[FIREBASE_ID_OF_STORE]"}
    ```
    
#### Security Endpoints

1. ```POST /jwt/refresh```
    - Creates a refresh JWT token if the user is a valid customer OR vendor
    - Expiry time: `60s`
    - Input (JSON Body):
    ```
    {
        "user_id":"3GpMaEm1DShNJzDFxTK853KsCYI3"
    }
    ```
    - Expected Output:
    ```
    {
        "token":"[SOME_TOKEN]"
    }
    ```

### Security
- JWT with HS256 (HMAC with SHA-256)
- Secret: 512 bit key in .env (or GCP for live secret)

### Test Cases
An ongoing list of corner cases to test for

#### Security
- Invalid JWT in `token` JSON field
- Expired JWT
- No `token` field passed
- Invalid user ID

## License

Copyright © 2019 Clerc Technology Inc, All rights reserved
