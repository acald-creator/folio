module Folio
  # Best-effort location filter for public board strings.
  # Boards do not share a country code, so this reads the free-text location.
  module Locations
    US_MARKERS = [
      /\bunited states\b/i,
      /\bu\.?\s*s\.?\s*a\.?\b/i,
      /\bremote[^a-z0-9]{0,12}u\.?\s*s\.?a?\b/i,
      /\bu\.?\s*s\.?\s*(remote|only|based)\b/i,
      /\b(alabama|alaska|arizona|arkansas|california|colorado|connecticut|delaware|florida|georgia|hawaii|idaho|illinois|indiana|iowa|kansas|kentucky|louisiana|maine|maryland|massachusetts|michigan|minnesota|mississippi|missouri|montana|nebraska|nevada|new hampshire|new jersey|new mexico|new york|north carolina|north dakota|ohio|oklahoma|oregon|pennsylvania|rhode island|south carolina|south dakota|tennessee|texas|utah|vermont|virginia|washington|west virginia|wisconsin|wyoming|district of columbia|washington,? d\.?c\.?)\b/i,
      /\b(san francisco|sf bay|bay area|los angeles|new york(?:\s*city)?|nyc|seattle|austin|chicago|boston|denver|atlanta|portland|miami|dallas|houston|philadelphia|minneapolis|detroit|san diego|san jose|oakland|brooklyn|manhattan)\b/i
    ].freeze

    US_STATE_CODES = %w[
      AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO
      MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC
    ].freeze

    module_function

    def us?(location)
      text = location.to_s.strip
      return false if text.blank? || text.match?(/\A(n\/?a|none|null|-)\z/i)

      return true if US_MARKERS.any? { |pattern| text.match?(pattern) }
      return true if state_code?(text)

      false
    end

    def state_code?(text)
      text.upcase.scan(/\b[A-Z]{2}\b/).any? { |token| US_STATE_CODES.include?(token) }
    end
  end
end
