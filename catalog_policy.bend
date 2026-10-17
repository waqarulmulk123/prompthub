import Base

# Catalog data can only ship when its license and safety review are recorded.
def publishable(licensed: Bool, safe: Bool) -> Bool:
  Bool.and(licensed, safe)

# Paid prompt text is omitted from the public CDN.
def public_text(pro: Bool, text: String) -> String:
  match pro:
    case True{}:
      ""
    case False{}:
      text

def validate_pair(left_license: Bool, left_safe: Bool, right_license: Bool, right_safe: Bool) -> Bool:
  a b = publishable(left_license, left_safe) publishable(right_license, right_safe)
  Bool.and(a, b)
