# encoding: utf-8
#
#  = Scientific Name
#
#  This class describes the data model for the class ScientificName, a subclass 
#  of SemanticVernacularDataSource. An instance of ScientificName class 
#  represents an associated scientific name for an SVD instance.
#
#  == Class Methods
#  === Public
#  insert::                   Overrdie the parent class method.
#  delete::                   Inherit the parent class method.
#  === Private
#  insert_triples::           Overrdie the parent class method.
#  delete_triples::           Override the parent class method.
#
#  == Instance Methods
#  ==== Private
#  query_attibutes::          Build a SPARQL query for getting attributes of an
#                             instance.
#
################################################################################

class ScientificName < SemanticVernacularDataSource

  attr_accessor :uri,
                # :creator,
                # :created_date_time,
                :label,
                :moURL,
                :moID

  def initialize(uri)
    @uri = uri
    sn = self.class.query(query_attributes)[0]
    @label = sn["label"]["value"]
    # @creator = SVUser.new(desc["user"]["value"])
    # @created_date_time = desc["dateTime"]["value"]
    @moURL = sn["moURL"] == nil ? nil : sn["moURL"]["value"]
    @moID = sn["moID"] == nil ? nil : sn["moID"]["value"]
  end

  def self.insert(svd, scientific_names)
    update(insert_triples(svd, scientific_names))
  end

  private

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?label ?moURL ?moID
      FROM <#{SVF_GRAPH}>
      WHERE {
        <#{@uri}> rdfs:subClassOf svf:ScientificName .
        <#{@uri}> rdfs:label ?label .
        OPTIONAL { <#{@uri}> svf:hasMushroomObserverURL ?moURL } .
        OPTIONAL { <#{@uri}> owl:equivalentClass ?c .
        ?c owl:onProperty svf:hasMONameId .
        ?c owl:hasValue ?moID . }})
  end

  def self.insert_triples(svd, scientific_names)
    rdf = QUERY_PREFIX + %(INSERT DATA { GRAPH <#{SVF_GRAPH}> {)
    scientific_names.each do |scientific_name|
      rdf << 
        %(<#{svd["uri"]}>
            rdfs:subClassOf
              #{insert_some_object_values_from_restriction_triples(
                SVF_NAMESPACE + "hasAssociatedScientificName", 
                scientific_name["uri"])} . 
          <#{scientific_name["uri"]}>
            rdfs:subClassOf svf:ScientificName;
            rdfs:label "#{scientific_name["label"]}"^^rdfs:Literal;
            svf:hasID "#{scientific_name["id"]}"^^xsd:integer . )
    end
    rdf << %(}})
    return rdf
  end

  def self.delete_triples(scientific_name)
    QUERY_PREFIX +
    %(DELETE WHERE {
        GRAPH <#{SVF_GRAPH}> {
          ?svd rdfs:subClassOf ?c . 
          ?c owl:someValuesFrom <#{scientific_name}> .
          ?c ?p1 ?o1 .
          <#{scientific_name}> ?p2 ?o2 . }})
  end

end