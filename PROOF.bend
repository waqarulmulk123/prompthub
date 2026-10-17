import Base
import ./LAWS.bend as Laws

def Laws.unlicensed_rejected(safe):
  {==}

def Laws.unsafe_rejected(licensed):
  match licensed:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.paid_text_private(text):
  {==}

def Laws.free_text_preserved(text):
  {==}

def Laws.duplicate_image_rejected(id_unique, prompt_unique):
  match id_unique prompt_unique:
    case False{} _:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def Laws.duplicate_prompt_rejected(id_unique, image_unique):
  match id_unique:
    case False{}:
      {==}
    case True{}:
      {==}
