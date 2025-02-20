# frozen_string_literal: true

class AssignmentRepo < ApplicationRecord
  include AssignmentRepoable

  update_index("assignment_repo#assignment_repo") { self }

  # TODO: remove this enum (dead code)
  enum configuration_state: %i[not_configured configuring configured]

  belongs_to :assignment
  belongs_to :repo_access, optional: true
  belongs_to :user

  has_one :organization, -> { unscope(where: :deleted_at) }, through: :assignment

  validates :assignment, presence: true

  validate :assignment_user_key_uniqueness

  # TODO: Remove this dependency from the model.
  before_destroy :silently_destroy_github_repository

  delegate :creator, :starter_code_repo_id, to: :assignment
  delegate :github_user,                    to: :user
  delegate :default_branch, :commits,       to: :github_repository
  delegate :github_team_id,                 to: :repo_access, allow_nil: true

  # Public: This method is used for legacy purposes
  # until we can get the transition finally completed
  #
  # NOTE: We used to create one person teams for Assignments,
  # however when the new organization permissions came out
  # https://github.com/blog/2020-improved-organization-permissions
  # we were able to move these students over to being an outside collaborator
  # so when we deleted the AssignmentRepo we would remove the student as well.
  #
  # Returns the User associated with the AssignmentRepo
  alias original_user user
  def user
    original_user || repo_access.user
  end

  private

  # Internal: Attempt to destroy the GitHub repository.
  #
  # Returns true.
  def silently_destroy_github_repository
    return true if organization.blank?

    organization.github_organization.delete_repository(github_repo_id)
    true
  rescue GitHub::Error
    true
  end

  # Internal: Validate uniqueness of <user, assignment> key.
  # Only runs the validation on new records.
  #
  def assignment_user_key_uniqueness
    return if persisted?
    return unless AssignmentRepo.find_by(user: user, assignment: assignment)
    errors.add(:assignment, "Should only have one assignment repository for each user-assignment combination")
  end
end
