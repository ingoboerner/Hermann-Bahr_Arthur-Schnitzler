xquery version "3.1";


(:~
Funktionen zur Modellierung der Daten als LOD
@author Ingo Börner
:)
module namespace lod="http://bahrschnitzler.acdh.oeaw.ac.at/lod";
import module namespace config="http://hbas.at/config" at "config.xqm";
import module namespace api="http://bahrschnitzler.acdh.oeaw.ac.at/api" at "api.xqm";

(: look up namespaces! :)
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace custom="https://bahrschnitzler.acdh.oeaw.ac.at/ns";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ;
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#" ;
declare namespace dc11="http://purl.org/dc/elements/1.1/" ;
declare namespace dct="http://purl.org/dc/terms/" ;
declare namespace crm="http://www.cidoc-crm.org/cidoc-crm/" ;
declare namespace gndo="http://d-nb.info/standards/elementset/gnd#" ;
declare namespace owl="http://www.w3.org/2002/07/owl#" ; 
declare namespace schema="http://schema.org/" ;

(:~ Returns data on a person as RDF :)
declare function lod:person($id as xs:string) {
    
        let $data := collection($config:data-root)/id($id)
        
        let $forename := $data//tei:forename
        let $surname := $data//tei:surname
        let $gnd := if ($data//tei:idno[@type='GND']/text()) then "http://d-nb.info/gnd/" || $data//tei:idno[@type='GND']/text() else ""

        
        let $label := $surname || ", " || $forename
        
        return
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/person/{$id}">
            <rdfs:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E21_Person"/>
            <rdfs:label>{$label}</rdfs:label>
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>
            {
                if ($gnd != "") then
                    <crm:P1_is_identified_by rdf:resource="{$gnd}"/>    
                else ()
            }
        </rdf:Description>
        
};

(:~ Returns data on a place as RDF :)
declare function lod:place($id) {
    
    let $data := collection($config:data-root)/id($id)
    let $label := $data//tei:placeName/string()
    (: upload the new place list and perform lookup to get better data and classification:)
     return
         
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/place/{$id}">
            <rdfs:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E53_Place"/>
            <rdfs:label>{$label}</rdfs:label>
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>
        </rdf:Description>
};


declare function lod:resource($id) {
    let $data := collection($config:data-root)/id($id)
    
    let $labels := for $titleString in local:getTitlesOfDoc($id) return
        <rdfs:label>{$titleString}</rdfs:label>
    
    let $titles := for $titleString in local:getTitlesOfDoc($id) return
        <dc11:title>{$titleString}</dc11:title>
    
    let $doctype := local:getDocumentTypeURI($id)
        
    let $date := <dct:date rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{api:DocSortDate($id)}</dct:date>
    
    let $creation := local:generateCreationActivities($id)
    
    (: mentions :)
    let $mentions := lod:getMentions($id)
    
    return 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/document/{$id}">
            {
                
            (
            <rdfs:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E73_Information_Object"/>,
            $labels,
            $creation,
            $date,
            <crm:P2_has_type rdf:resource="{$doctype}"/>, 
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>,
            $mentions
            
            )
                
            }
        </rdf:Description>
    
};

(: local:getAuthorsOfDoc :)
declare function local:getAuthorsOfDoc($docId as xs:string) {
    (:~ Helper Function returns  IDs of Authors of a Document as sequence
    : @param $docId xml:id of the document
    : @returns sequence of ids
    :)
    
    (: check, if correct form of ID :)
    
    if (matches($docId, '[DLT][0-9]{6}')) then
        
        (: check if Document exists :)
        if (collection($config:data-root)/id($docId)) then
            
            for $authorkey in collection($config:data-root)/id($docId)//tei:titleStmt//tei:author/@key/string()
            return $authorkey
            
            
            else <error>No such document</error>
        
    else 
        <error>Incorrect DocId</error>
    
};

(: local:getTitlesOfDoc :)
declare function local:getTitlesOfDoc($docId as xs:string) {
    (:~ Helper Function returns the titles of Documents 
    @param $docId 
    @returns sequence of Titles
    :)
    
    (: check, if correct docId :)
    if (matches($docId, '[DLT][0-9]{6}')) then
        
        (: check if Document exists :)
        if (collection($config:data-root)/id($docId)) then
            
            for $title in collection($config:data-root)/id($docId)//tei:titleStmt//tei:title[@level='a']
            return normalize-space($title/text())
            
            
            else <error>No such document</error>
        
    else 
        <error>Incorrect DocId</error>
    
    
};

declare function local:getEntityType($id) {
    switch ( collection($config:data-root)/id($id)/name() ) 
    case "person" return "person"
    case "TEI" return "document"
    case "place" return "place"
    default return "entity"
};

declare function lod:getMentions($id as xs:string) {
    
    (: check if document exists :)
    if (collection($config:data-root)/id($id)) then
        (:Doc exists, return tei:teiHeader:)
    
   
        (: loop over all Elements with a @key-Attribute – and hope, that these are the mentions.. :)
        for $key in distinct-values(collection($config:data-root)/id($id)//tei:body//element()[@key]/@key/string())
        return
            <schema:mentions xmlns:schema="http://schema.org/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/{local:getEntityType($key)}/{$key}"/>
   

else
    ()
};


(:~ Get the URI of a Document-Type :)
declare function local:getDocumentTypeURI($id) {
    (: http://bahrschnitzler.acdh.oeaw.ac.at/type/ :)
    (: perform a lookup in titleList 2DO:)
    
    
    let $sigla := substring($id, 1,1) 
    let $doc := collection($config:data-root)/id($id)
    
    let $type := switch (substring($id,1,1)) 
        
        case "T" return "text"
        case "D" return "document"
        case "L" return "letter"
        
        default return "unknown"
        
    let $uri := "http://bahrschnitzler.acdh.oeaw.ac.at/type/" || $type
    
    
    return 
        $uri
};


declare function local:generateCreationActivities($id) {
    
    <crm:P94i_was_created_by xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/">
      <rdf:Description>
        { 
            for $creator in local:getAuthorsOfDoc($id) return 
                <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/person/{$creator}"/>
        }
      </rdf:Description>
    </crm:P94i_was_created_by>
};

declare function local:getAuthorsOfDoc($docId as xs:string) {
    (:~ Helper Function returns  IDs of Authors of a Document as sequence
    : @param $docId xml:id of the document
    : @returns sequence of ids
    :)
    
    (: check, if correct form of ID :)
    
    if (matches($docId, '[DLT][0-9]{6}')) then
        
        (: check if Document exists :)
        if (collection($config:data-root)/id($docId)) then
            
            for $authorkey in collection($config:data-root)/id($docId)//tei:titleStmt//tei:author/@key/string()
            return $authorkey
            
            
            else <error>No such document</error>
        
    else 
        <error>Incorrect DocId</error>
    
};