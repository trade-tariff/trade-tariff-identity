require "rails_helper"

RSpec.describe CognitoTokenVerifier do
  describe ".call" do
    let(:token) { "test-token" }
    let(:consumer) { build(:consumer, id: "myott") }
    let(:jwks_url) { "https://cognito-idp.#{ENV['AWS_REGION']}.amazonaws.com/#{ENV['COGNITO_USER_POOL_ID']}/.well-known/jwks.json" }
    let(:jwks_keys) { { "keys" => [{ "kty" => "RSA", "kid" => "test-kid", "use" => "sig" }] } }
    let(:decoded_token) { [{ "sub" => "1234567890", "email" => "test@example.com", "cognito:groups" => %w[myott] }] }

    before do
      allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: true, body: jwks_keys.to_json))
      allow(EncryptionService).to receive(:decrypt_string).and_return(token)
      allow(JWT).to receive(:decode).and_return(decoded_token)
    end

    context "when the token is valid" do
      it "returns :valid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:valid)
      end

      it "verifies the token" do
        described_class.call(token, consumer)
        expect(JWT).to have_received(:decode).with(token, nil, true, algorithms: %w[RS256], jwks: hash_including(:keys), iss: anything, verify_iss: true)
      end
    end

    context "when the token is valid but not in the expected group" do
      let(:decoded_token) { [{ "sub" => "1234567890", "email" => "test@example.com", "cognito:groups" => %w[other] }] }

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq :invalid
      end
    end

    context "when the token is blank" do
      let(:token) { nil }

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when the JWKS response is unsuccessful" do
      before do
        allow(Faraday).to receive(:get).with(jwks_url).and_return(instance_double(Faraday::Response, success?: false))
      end

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when an error occurs during token verification" do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::DecodeError)
      end

      it "returns :invalid" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:invalid)
      end
    end

    context "when the token is expired" do
      before do
        allow(JWT).to receive(:decode).and_raise(JWT::ExpiredSignature)
      end

      it "returns :expired" do
        result = described_class.call(token, consumer)
        expect(result).to eq(:expired)
      end
    end
  end
end
