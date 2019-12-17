# @summary
#   Generates a random string of specific length.
#
# @example Generate a random string of length 8:
#   rand_string(8)
#
# @example Generate a random string from a specific set of characters:
#   seeded_rand_string(5, 'abcdef')
Puppet::Functions.create_function(:rand_string) do
  # @param length Length of string to be generated.
  # @param charset String that contains characters to use for the random string.
  #
  # @return [String] Random string.
  dispatch :rand_string do
    param 'Integer[1]', :length
    optional_param 'String[2]', :charset
  end

  def rand_string(length, charset = nil)
    require 'digest/sha2'

    charset ||= '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

    random_generator = Random.new()

    Array.new(length) { charset[random_generator.rand(charset.size)] }.join
  end
end
