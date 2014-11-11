module PivotalTracker
  class Story
    attr_accessor :requester
    attr_accessor :developers
    attr_accessor :reviewers
    attr_accessor :qa
    attr_accessor :github_urls
  end
end

class IterationPresenter
  attr_accessor :selected_project_id
  attr_accessor :my_stories_only
  attr_accessor :show_last_week
  attr_reader   :updated_at

  def initialize(api_token)
    raise ArgumentError unless api_token
    PivotalTracker::Client.token = api_token
    @updated_at = Time.now
  end

  def me
    @me ||= PivotalTracker::Me.all
  end

  def projects
    @projects ||= PivotalTracker::Project.all("fields=name,current_velocity").
      delete_if { |project| project.name.starts_with?("Onstride") }.
      map { |project| project.name.gsub!("NetCredit - ", ""); project }.
      sort { |a, b| a.name <=> b.name }
  end

  def projects_velocity
    @projects_velocity ||= projects.map(&:current_velocity).inject(:+)
  end

  def columns
    columns = [
      { title: "Planned",       stories: planned_stories },
      { title: "Started",       stories: started_stories },
      { title: "Ready for CR",  stories: finished_stories },
      { title: "Ready for QA",  stories: reviewed_stories },
      { title: "Delivered",     stories: delivered_stories + accepted_stories},
      { title: "Released",      stories: released_stories }
    ]

    columns.each do |column|
      column[:total] = column[:stories].sum { |story| story.estimate.to_i }
    end
  end

  def released_last_week_stories
    stories.select { |story| released_story?(story) && last_week_story?(story) }
  end

  def released_last_week_total
    released_last_week_stories.sum { |story| story.estimate.to_i }
  end

  def iteration_date_range
    "#{Date.current.beginning_of_week} - #{Date.current.end_of_week}"
  end

  def project_iteration_estimates
    @project_iteration_estimates ||= begin
      all_stories.each_with_object({}) do |(project_id, stories), hash|
        stories.keep_if {|story| my_story?(story) } if my_stories_only
        hash[project_id] = stories.select { |story| !released_last_week_stories.include?(story) }.
          sum { |story| story.estimate.to_i }
      end
    end
  end

  def all_iteration_estimate
    project_iteration_estimates.values.inject(:+)
  end

  def my_iteration_estimate
    all_stories.values.flatten.select {|story| my_story?(story) }.sum { |story| story.estimate.to_i }
  end

  private

    def planned_stories
      stories.select { |story| story.current_state == "planned" }
    end

    def started_stories
      stories.select { |story| story.current_state == "started" }
    end

    def finished_stories
      stories.select { |story| story.current_state == "finished" }.
        reject { |story| reviewed_stories.include? story }
    end

    def reviewed_stories
      stories.select { |story| story.labels.map(&:name).include?("ready for qa") }
    end

    def delivered_stories
      stories.select { |story| story.current_state == "delivered" }
    end

    def accepted_stories
      stories.select { |story| story.current_state == "accepted" && !released_story?(story)}
    end

    def released_stories
      stories.select { |story| released_story?(story) && !last_week_story?(story)}
    end

    def released_story?(story)
      labels = story.labels.map(&:name)
      story.current_state == "accepted" && (
        labels.include?("released") ||
        labels.include?("will not do") ||
        story.story_type == "chore"
      )
    end

    def last_week_story?(story)
      story.current_state == "accepted" && story.accepted_at < Date.current.beginning_of_week
    end

    def iteration_stories_filter
      "(state:planned OR state:started OR state:finished OR state:delivered OR \
       accepted_after:#{Date.current.beginning_of_week - 1.week}) includedone:true -type:release"
    end

    def people
      @people ||= projects.map { |project| project.memberships.all.map(&:person) }.flatten.uniq
    end

    def person_by_initials(initials)
      people.find { |person| person.initials == initials }
    end

    def initials_from_description(story, role)
      story.description.to_s[/#{role}:\s*(.*)\s*/, 1].try(:strip)
    end

    def github_urls_from_description(story)
      story.description.to_s.scan(/(https:\/\/git.enova.com\/\S+)/).map(&:first)
    end

    def all_stories
      @all_stories ||= {}.tap do |hash|
        projects.each { |project| hash[project.id] = initialize_people_objects(project.stories.all(search: iteration_stories_filter)) }
      end
    end

    def stories
      stories = if selected_project_id
        all_stories[selected_project_id]
      else
        all_stories.values.inject(:+)
      end
      stories.keep_if { |story| my_story?(story) } if my_stories_only
      stories.sort_by { |story| [story.project_id, story.id] }
    end

    def initialize_people_objects(stories)
      stories.map do |story|
        reviewer_initials = [initials_from_description(story, "CR1"), initials_from_description(story, "CR2")].compact
        qa_initials       = initials_from_description(story, "QA").to_s.split(",").map(&:strip)
        story.requester   = people.find { |person| story.requested_by_id == person.id }
        story.developers  = people.select { |person| story.owner_ids.include? person.id }
        story.reviewers   = reviewer_initials.map { |initials| person_by_initials(initials) }.compact
        story.qa          = qa_initials.map { |initials| person_by_initials(initials) }.compact
        story.github_urls = github_urls_from_description(story)
        story.estimate    = 0 if story.labels.map(&:name).include?("will not do")
        story
      end
    end

    def my_story?(story)
      (story.developers + story.reviewers + story.qa).include? person_by_initials(me.initials)
    end
end
