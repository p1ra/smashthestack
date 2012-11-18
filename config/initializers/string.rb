class String
  def translate(params)
    Translator.translate(params.merge!(text: self)).first.translation
  end
  def translate!(params)
    replace translate(params)
  end
  def translatable?
    self.normalize.strip[/[^\p{^Word}\p{Digit}]+/um]
  end
  def normalize(params={})
    Normalizer.new(self).normalize_utf8
  end
  def normalize!(params={})
    self.replace(Normalizer.new(self).normalize_utf8)
  end  
end
