class File
  def original_filename
    self.class.basename self
  end
end
