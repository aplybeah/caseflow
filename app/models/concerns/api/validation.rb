# frozen_string_literal: true

module Api::Validation
  extend ActiveSupport::Concern
  include Api::Helpers

  def int?(value, key: nil, exception: ArgumentError)
    return true if !value.nil? && value == to_int(value)
    fail exception, join_present(key, "isn't an int : <#{value}>") if exception

    false
  end

  def int_or_int_string?(value, key: nil, exception: ArgumentError)
    return true if int?(value, exception: nil) || (to_int(value) && to_int(value) == to_float(value))

    message = "is neither an int nor a string that can be converted to an int: <#{value}>"
    fail exception, join_present(key, message) if exception

    false
  end

  def present?(value, key: nil, exception: ArgumentError)
    value.present? || (exception ? fail(exception, join_present(key, "is blank: <#{value.inspect}>")) : false)
  end

  def nullable_array?(value, key: nil, exception: ArgumentError)
    return true if value.nil? || value.is_a?(Array)
    fail exception, join_present(key, "is neither an array nor nil: <#{value}>") if exception

    false
  end

  def string?(value, key: nil, exception: ArgumentError)
    value.is_a?(String) || (exception ? fail(exception, join_present(key, "is not a string: <#{value}>")) : false)
  end

  def nullable_string?(value, key: nil, exception: ArgumentError)
    value.nil? || string?(value, key: key, exception: exception)
  end

  # date string: "YYYY-MM-DD"
  def date_string?(value, key: nil, exception: ArgumentError)
    return true if begin
      Date.valid_date?(*(value.split("-").map { |s| to_int s }))
                   rescue StandardError # if the splitting raises an exception
                     false
    end

    fail exception, join_present(key, "is not a date string: <#{value}>") if exception

    false
  end

  def nullable_date_string?(value, key: nil, exception: ArgumentError)
    value.nil? || date_string?(value, key: key, exception: exception)
  end

  def boolean?(value, key: nil, exception: ArgumentError)
    return true if value.is_a?(TrueClass) || value.is_a?(FalseClass)
    fail exception, join_present(key, "is not a boolean: <#{value}>") if exception

    false
  end

  def true?(value, key: nil, exception: ArgumentError)
    (value == true) || (exception ? fail(exception, join_present(key, "is not true: <#{value}>")) : false)
  end

  def null_or_benefit_type?(value, key: nil, exception: ArgumentError)
    return true if value.nil? || Api::HigherLevelReviewPreintake::BENEFIT_TYPES[value]
    fail exception, join_present(key, "is not a benefit type (line of business): <#{value}>") if exception

    false
  end

  def null_or_nonrating_issue_category_for_benefit_type?(category, benefit_type, exception: ArgumentError)
    return true if category.nil? || category.in?(
      Api::HigherLevelReviewPreintake::NONRATING_ISSUE_CATEGORIES[benefit_type] || []
    )
    fail exception, "<#{category}> is not a valid category for benefit_type: <#{benefit_type}>" if exception

    false
  end

  def payee_code?(value, key: nil, exception: ArgumentError)
    return true if value.in? Api::HigherLevelReviewPreintake::PAYEE_CODES
    fail exception, join_present(key, "is not a valid payee code: <#{value}>") if exception

    false
  end

  def any_present?(*values, keys:, exception: ArgumentError)
    values.any?(&:present?) || (exception ? fail(exception, "at least one must be present: #{keys}") : false)
  end

  def hash_keys_are_within_this_set?(hash, keys:, exception: ArgumentError)
    extras = extra_keys hash, expected_keys: keys
    return true if extras.empty?
    fail exception, "hash has extra keys: #{extras}" if exception

    false
  end

  def hash_has_at_least_these_keys?(hash, keys:, exception: ArgumentError)
    missing = missing_keys hash, expected_keys: keys
    return true if missing.empty?
    fail exception, "hash is missing keys: #{missing}" if exception

    false
  end

  def these_are_the_hash_keys?(hash, keys:, exception: ArgumentError)
    extras = extra_keys hash, expected_keys: keys
    missing = missing_keys hash, expected_keys: keys
    return true if extras.empty? && missing.empty?

    message = join_present(
      extras.present? && "hash has extra keys: #{extras}",
      missing.present? && "hash is missing keys: #{missing}"
    )
    fail exception, message if exception

    false
  end
end
