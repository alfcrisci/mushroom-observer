class ObservationConsensus
  attr_accessor :consensus
  
  def initialize
    self.consensus = nil
    @max_score = Vote.minimum_vote - 1
  end
  
  def add_naming(naming)
    if naming.vote_cache > @max_score
      @max_score = naming.vote_cache
      self.consensus = naming
    end
  end
end
