# frozen_string_literal: true

require "lutaml/model"

# Citation model representing bibliographic references
class Citation < Lutaml::Model::Serializable
  attribute :id, :string
  attribute :title, :string
  attribute :author, :string
  attribute :publisher, :string
  attribute :edition, :string
  attribute :edition_date, :string
  attribute :revision_date, :string
  attribute :series_name, :string
  attribute :series_issue_id, :string
  attribute :series_page, :string
  attribute :isbn, :string
  attribute :issn, :string
  attribute :other_details, :string
  attribute :uuid, :string
  attribute :variants, :string, collection: true

  yaml do
    map "id", to: :id
    map "title", to: :title
    map "author", to: :author
    map "publisher", to: :publisher
    map "edition", to: :edition
    map "editionDate", to: :edition_date
    map "revisionDate", to: :revision_date
    map "seriesName", to: :series_name
    map "seriesIssueID", to: :series_issue_id
    map "seriesPage", to: :series_page
    map "isbn", to: :isbn
    map "issn", to: :issn
    map "otherDetails", to: :other_details
    map "uuid", to: :uuid
    map "variants", to: :variants
  end

  def to_h
    hash = {}
    hash["id"] = id if id
    hash["title"] = title if title
    hash["author"] = author if author
    hash["publisher"] = publisher if publisher
    hash["edition"] = edition if edition
    hash["editionDate"] = edition_date if edition_date
    hash["revisionDate"] = revision_date if revision_date
    hash["seriesName"] = series_name if series_name
    hash["seriesIssueID"] = series_issue_id if series_issue_id
    hash["seriesPage"] = series_page if series_page
    hash["isbn"] = isbn if isbn
    hash["issn"] = issn if issn
    hash["otherDetails"] = other_details if other_details
    hash["uuid"] = uuid if uuid
    hash["variants"] = variants if variants && !variants.empty?
    hash
  end
end