class ObservationConsensus
  def initialize
    @namings = Set.new()
  end
  
  def add_naming(naming)
    @namings.add(naming)
  end
  
  def consensus
    result = nil
    max_score = Vote.minimum_vote - 1
    synonyms = Set.new()
    for naming in @namings
      unless naming.is_repeat?(synonyms)
        best_naming = naming.best_naming(@namings)
        score = best_naming.score(@namings)
        if score > max_score
          result = best_naming
          max_score = score
        end
      end
    end
    result
  end
end
