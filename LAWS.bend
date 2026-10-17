import Base
import ./catalog_policy.bend as Policy

law unlicensed_rejected:
  for safe: Bool
  {Policy.publishable(False{}, safe) == False{} : Bool}

law unsafe_rejected:
  for licensed: Bool
  {Policy.publishable(licensed, False{}) == False{} : Bool}

law paid_text_private:
  for text: String
  {Policy.public_text(True{}, text) == "" : String}

law free_text_preserved:
  for +text: String
  {Policy.public_text(False{}, text) == text : String}

# Server engagement invariants are exercised transactionally in supabase/engagement_security_test.sql:
# one claim per server day; one reward per seven consecutive claims; permanent private claims;
# quota reservations refund on provider failure; private Brand DNA; reviewed remixes; unique votes.
