module IterationHelper
  def story_icon(type)
    case type
    when "bug" then content_tag(:span, "", class: "fa fa-bug")
    when "chore" then content_tag(:span, "", class: "glyphicon glyphicon-cog")
    when "feature" then content_tag(:span, "", class: "glyphicon glyphicon-star")
    end
  end

  def story_state_color(story)
    return "danger" if story.labels.map(&:name).include? "will not do"
    case story.current_state
    when "started"                then "info"
    when "finished"               then "warning"
    when "delivered", "accepted"  then "success"
    else "default"
    end
  end

  def role_initials(story, role)
    role_initials = initials(story.send(role))

    label = role_label(role)

    if needs_role_assigned?(role, story) && role_initials.blank?
      content_tag(:span, "Need #{label}", class: "label label-danger")
    elsif !role_initials.blank?
      "#{label}: #{role_initials}"
    end

  end

  def last_updated
    if @iteration_presenter.updated_at
      updated_ago = time_ago_in_words @iteration_presenter.updated_at
      content_tag(:span, "(last updated #{updated_ago} ago)", class: "small")
    end
  end

  def my_stories_only_path
    url_for(toggle_param(:my_stories_only))
  end

  def show_last_week_path
    url_for(toggle_param(:show_last_week))
  end

  private
    def toggle_param(param)
      if params[param]
        params.except(param)
      else
        params.merge(param => true)
      end
    end

    def initials(people)
      people = [people].compact unless people.is_a? Array
      people.map { |person| content_tag(:strong, content_tag(:abbr, person.initials, title: person.name, class: "initialism")) }.join ", "
    end

    def role_label(role)
      case role
      when "requester" then "Req"
      when "developers" then "Dev"
      when "reviewers" then "CR"
      when "qa" then "QA"
      end
    end

    def needs_role_assigned?(role, story)
      return false if story.story_type == "chore"
      case role
      when "developers" then ["started", "finished", "delivered", "accepted"].include?(story.current_state)
      when "reviewers", "qa" then ["finished", "delivered", "accepted"].include?(story.current_state)
      end
    end
end
