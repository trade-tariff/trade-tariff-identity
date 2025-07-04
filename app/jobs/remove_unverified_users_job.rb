class RemoveUnverifiedUsersJob < ApplicationJob
  queue_as :default

  def perform
    client = TradeTariffIdentity.cognito_client
    user_pool_id = TradeTariffIdentity.cognito_user_pool_id
    pagination_token = nil

    loop do
      response = client.list_users({
        user_pool_id:,
        pagination_token:,
      }.compact)

      response.users.each do |user|
        created_at = user.user_create_date
        verified = user.attributes.find { |attr| attr.name == "email_verified" }&.value == "true"

        next if verified || created_at > 1.day.ago

        groups_response = client.admin_list_groups_for_user({
          user_pool_id:,
          username: user.username,
        })

        in_myott_group = groups_response.groups.any? { |group| group.group_name == ENV["MYOTT_ID"] }

        next unless in_myott_group

        client.admin_delete_user({
          user_pool_id:,
          username: user.username,
        })
      end

      break unless response.pagination_token

      pagination_token = response.pagination_token
    end
  end
end
