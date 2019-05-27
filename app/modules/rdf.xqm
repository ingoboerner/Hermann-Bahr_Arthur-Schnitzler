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
declare namespace geo="http://www.opengis.net/ont/geosparql#" ;


declare variable $lod:additonal_data-root := $config:app-root || "/additional_data";

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
    let $additional_data := collection($lod:additonal_data-root)//tei:idno[@type="ASBW"][contains(./text(),$id)]/ancestor::tei:place
    let $label := $data//tei:placeName/string()
    
    
    (: get better data and classification from hbas_places in additional_data:)
    let $placetype := $additional_data/@type/string()
    let $wikidata := $additional_data//tei:idno[@subtype="WIKIDATA"]/string()
    let $geonames := $additional_data//tei:idno[@subtype="GEONAMES"]/string()
    let $coords := $additional_data//tei:geo/string()
    let $lon := tokenize($coords,' ')[2]
    let $lat := tokenize($coords, ' ')[1]
    let $wienwiki := normalize-space($additional_data//tei:idno[@subtype="WIENWIKI"]/string())
     return
         
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/place/{$id}">
            <rdfs:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E53_Place"/>
            
            <crm:P1_is_identified_by>
                <crm:E41_Appellation>
                    <rdfs:label xml:lang="de">{$label}</rdfs:label>
                </crm:E41_Appellation>
            </crm:P1_is_identified_by>
            
            <rdfs:label>{$label}</rdfs:label>
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>
            {
                if ($placetype != '') then 
                    <crm:P2_has_type rdf:resource="http://vocabs.acdh.ac.at/pmb-placetypes/{$placetype}"/>
                else ()
            }
            {
              (: Wikidata http://wikidata.org/entity/ :)
              if ($wikidata != '') then
                  for $string in $wikidata return 
                    <owl:sameAs rdf:resource="http://wikidata.org/entity/{$string}"/>
                  else ()
            }
            {
                (: Geonames :)
                if ($geonames != '') then
                  for $string in $geonames return
                    <owl:sameAs rdf:resource="http://sws.geonames.org/{$string}"/>
                  else ()
            }
            {
                if ($coords != "") then
                    <crm:P168_place_is_defined_by>Point({$lon || " " || $lat})</crm:P168_place_is_defined_by>
                else
                    ()
            }
            {
                (: Wienwiki :)
                (: http://www.geschichtewiki.wien.gv.at/Special:URIResolver/Salesianergasse :)
                (: T%C3%BCrkenschanzpark :)
                if ($wienwiki != '') then
                    for $string in $wienwiki return
                        <owl:sameAs rdf:resource="http://www.geschichtewiki.wien.gv.at/Special:URIResolver/{$string}"/>
                  else ()
                
            }
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
    
    let $corresp-events := if (substring($id,1,1) eq "L") then lod:getCorrespondenceEvents($id) else ()
    
    (: try to get identifier of theatermuseum :)
    let $theatermuseum := if ($data//tei:listWit[1]/tei:msIdentifier/tei:repository[contains(.,"Theatermuseum")]) then 
        local:getTheatermuseumID($id) else ()
    
    (: mentions :)
    let $mentions := lod:getMentions($id)
    
    return 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/document/{$id}">
            {
                
            (
            <rdfs:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E73_Information_Object"/>,
            $labels ,
            $creation ,
            $corresp-events ,
            $date,
            <crm:P2_has_type rdf:resource="{$doctype}"/>, 
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>,
            <crm:P1_is_identified_by>{$theatermuseum}</crm:P1_is_identified_by> ,
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

declare function lod:getCorrespondenceEvents($id as xs:string) {
    let $correspDesc := collection($config:data-root)/id($id)//tei:correspDesc
    let $senders := $correspDesc/tei:sender/tei:persName/@key/string()
    let $placeSender := $correspDesc/tei:placeSender/tei:placeName/@key/string()
    let $sendDate := $correspDesc/tei:dateSender/tei:date/@when/string()
    let $date-parsed := if ( matches( $sendDate,'[0-9]{8}') ) then substring($sendDate,1,4) || "-" || substring($sendDate,5,2) || "-" || substring($sendDate,7,2)  else ()
    let $addressees := $correspDesc/tei:addressee/tei:persName/@key/string()
    let $placeAddressee := $correspDesc/tei:placeAddressee/tei:placeName/@key/string()
    return 
        (
        <crm:P12i_was_present_at xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/">
            <crm:E7_Activity>
                <rdfs:label xml:lang="en">Sending of Letter {$id}</rdfs:label>
                <rdfs:label xml:lang="de">Senden des Briefes {$id}</rdfs:label>
                <crm:P2_has_type rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/type/SendingOfLetter"/>
                {
                    for $sender in $senders return
                        <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/person/{$sender}"/>
                }
                {
                    for $place in $placeSender return
                        <crm:P7_took_place_at rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/place/{$place}"/>
                }
                {
                    <crm:P4_has_time-span>
                        <crm:E52_Time-Span>
                            <crm:P82a_begin_of_the_begin rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date-parsed}</crm:P82a_begin_of_the_begin>
                            <crm:P82b_end_of_the_end rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date-parsed}</crm:P82b_end_of_the_end>
                        </crm:E52_Time-Span>
                    </crm:P4_has_time-span>
                }
                
            </crm:E7_Activity>
        </crm:P12i_was_present_at> ,
        
        <crm:P12i_was_present_at xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/">
            <crm:E7_Activity>
                <rdfs:label xml:lang="en">Receiving of Letter {$id}</rdfs:label>
                <rdfs:label xml:lang="de">Empfang des Briefes {$id}</rdfs:label>
                <crm:P2_has_type rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/type/ReceivingOfLetter"/>
                {
                    for $addressee in $addressees return
                        <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/person/{$addressee}"/>
                }
                {
                    for $place in $placeAddressee return
                        <crm:P7_took_place_at rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/place/{$place}"/>
                }
            </crm:E7_Activity>
        </crm:P12i_was_present_at>
        
        
        )
};

declare function local:getTheatermuseumID($id as xs:string) {
    let $signatur := collection($config:data-root)/id($id)//tei:msIdentifier[contains(./tei:repository,'Theatermuseum')]/tei:idno/string()
    return
        $signatur
};