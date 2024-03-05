=begin
=end
class Language::Message < Itefu::Language::Message
  attr_reader :chain

  def apply_chain(chain)
    @chain = chain
  end

  def text(id)
    super || chain && chain.text(id)
  end

end

