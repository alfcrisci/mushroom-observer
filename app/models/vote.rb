# encoding: utf-8
#
#  = Vote Model
#
#  Model describing a single vote for a single Naming.  Methods for dealing
#  with Vote's are all moved up to either Naming or Observation, depending on
#  whether all the information required for the operation is contained within
#  a single Naming or not.  Vote is responsible for very little except holding
#  the value.
#
#  Observation#change_vote::         Change a User's Vote for a given Naming.
#  Observation#calc_consensus::      Decide which Name is winner for an Observation.
#  Observation#is_owners_favorite?:: Is a given Naming the Observation owner's favorite?
#  Observation#is_users_favorite?::  Is a given Naming the given User's favorite?
#  Observation#refresh_vote_cache::  Refresh vote cache for all Observation's.
#
#  Naming#vote_sum::            Straight sum of Vote's for this Naming (used in tests).
#  Naming#user_voted?::         Has a given User voted for this Naming?
#  Naming#users_vote::          Get a given User's Vote for this Naming.
#  Naming#vote_percent::        Convert score for this Naming into a percentage.
#  Naming#is_users_favorite?::  Is this Naming the given User's favorite?
#  Naming#calc_vote_table::     Gather Vote info for this Naming.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  sync_id::            Globally unique alphanumeric id, used to sync with remote servers.
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  user::               User that created it.
#  value::              Value of Vote, a Float: 3.0 = 100%, -3.0 = -100%
#  naming::             Naming we're voting on.
#  observation::        Observation the Naming belongs to.
#  favorite::           Is this the User's favorite Vote for this Observation?
#
#  == Class methods
#
#  ==== Vote values
#  delete_vote::        Value of the special "delete" vote.
#  minimum_vote::       Value of the weakest nonzero vote.
#  min_neg_vote::       Value of the least negative vote.
#  min_pos_vote::       Value of the least positive vote.
#  next_best_vote::     Value of the next-to-best vote.
#  maximum_vote::       Value of the strongest vote.
#  percent::            Convert value to percentage.
#
#  ==== Vote labels
#  confidence_menu::    Structure used by form helper +select+ to create pulldown menu.
#  confidence::         Classify value as confidence level, String.
#
#  == Instance methods
#
#  percent::            Return value as percentage.
#  user_weight::        Calculate weight from user's contribution.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Vote < AbstractModel
  belongs_to :user
  belongs_to :naming
  belongs_to :observation

  # ----------------------------
  #  :section: Values
  # ----------------------------

  DELETE_VOTE    =  0
  MINIMUM_VOTE   = -3
  MIN_NEG_VOTE   = -1
  MIN_POS_VOTE   =  1
  NEXT_BEST_VOTE =  2
  MAXIMUM_VOTE   =  3

  # Override the default show_controller
  def self.show_controller
    'observer'
  end

  # This is used to mean "delete my vote".
  def self.delete_vote
    DELETE_VOTE
  end

  # Weakest nonzero vote.
  def self.minimum_vote
    MINIMUM_VOTE
  end

  # Least-negative vote.
  def self.min_neg_vote
    MIN_NEG_VOTE
  end

  # Least-positive vote.
  def self.min_pos_vote
    MIN_POS_VOTE
  end

  # Next-to-best vote.
  def self.next_best_vote
    NEXT_BEST_VOTE
  end

  # Strongest vote.
  def self.maximum_vote
    MAXIMUM_VOTE
  end

  # Convert a given Vote value to a percentage.
  def self.percent(v)
    if v.blank?
      0.0
    else
      v.to_f * 100 / 3
    end
  end

  # Convert Vote's value to a percentage.
  def percent
    self.class.percent(value)
  end

  # Validate a vote value.  Returns Float value if valid, nil otherwise.
  def self.validate_value(val)
    val = val.to_f
    val && val >= MINIMUM_VOTE && val <= MAXIMUM_VOTE ? val : nil
  rescue
    nil
  end

  # ----------------------------
  #  :section: Labels
  # ----------------------------

  CONFIDENCE_VALS = [
    [ :vote_confidence_100,  3 ],
    [ :vote_confidence_80,   2 ],
    [ :vote_confidence_60,   1 ],
    [ :vote_confidence_40,  -1 ],
    [ :vote_confidence_20,  -2 ],
    [ :vote_confidence_0,   -3 ]
  ]

  NO_OPINION_VAL = [:vote_no_opinion, 0]

  # Force unit tests to verify existence of these translations.
  if false
    :vote_confidence_100.l
    :vote_confidence_80.l
    :vote_confidence_60.l
    :vote_confidence_40.l
    :vote_confidence_20.l
    :vote_confidence_0.l
    :vote_no_opinion.l
  end

  # List of options interpreted as "confidence".
  #
  #   for label, value in Vote.confidence_menu
  #     puts "#{label.l} #{value}"
  #   end
  #
  def self.confidence_menu
    CONFIDENCE_VALS
  end

  def self.no_opinion
    :vote_no_opinion.l
  end

  def self.opinion_menu
    [NO_OPINION_VAL] + confidence_menu
  end
  
  # Find label of closest value in the "confidence" menu.
  def self.confidence(val)
    lookup_value(val, confidence_menu)
  end

  # ----------------------------
  #  :section: Other
  # ----------------------------

  LOG10 = Math.log(10)

  # Calculate user weight from contribution score.  Weight is logarithmic:
  #
  #   weight = log10(contribution) + 1   # owner of observation
  #   weight = log10(contribution)       # all other users
  #   weight = 0                         # if contribution <= 1
  #
  def user_weight
    contrib = user ? user.contribution : 0
    contrib = contrib < 1 ? 0 : Math.log(contrib) / LOG10
    contrib += 1 if observation && user == observation.user
    return contrib
  end

  # I want to turn this silly logic into an explicit boolean in the table.
  # This is the first step: abstracting it as a method on Vote instance.
  # Now we are free to change the implementation later.
  def anonymous?
    (user.votes_anonymous == :no) or
    (user.votes_anonymous == :old and updated_at > Time.parse(VOTE_CUTOFF))
  end

################################################################################

protected

  # Find label of closest value in a given enumerated lists.
  def self.lookup_value(val, list) # :nodoc:
    last_pair = nil
    for pair in list
      if pair[1] != 0
        if !last_pair.nil? && val > (last_pair[1] + pair[1]) / 2
          return last_pair[0]
        end
        last_pair = pair
      end
    end
    return last_pair[0]
  end

  def validate # :nodoc:
    if !self.naming
      errors.add(:naming, :validate_vote_naming_missing.t)
    end
    if !self.user && !User.current
      errors.add(:user, :validate_vote_user_missing.t)
    end

    if self.value.nil?
      errors.add(:value, :validate_vote_value_missing.t)
    elsif self.value_before_type_cast.to_s !~ /^[+-]?\d+(\.\d+)?$/
      errors.add(:value, :validate_vote_value_not_integer.t)
    elsif self.value < MINIMUM_VOTE || self.value > MAXIMUM_VOTE
      errors.add(:value, :validate_vote_value_out_of_bounds.t)
    end
  end
end
