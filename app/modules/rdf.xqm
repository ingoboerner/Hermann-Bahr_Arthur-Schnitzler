xquery version "3.1";


(:~
Funktionen zur Modellierung der Daten als LOD
@author Ingo Börner
:)
module namespace lod="http://bahrschnitzler.acdh.oeaw.ac.at/lod";
import module namespace config="http://hbas.at/config" at "config.xqm";
import module namespace api="http://bahrschnitzler.acdh.oeaw.ac.at/api" at "api.xqm";

import module namespace http="http://expath.org/ns/http-client";

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
declare namespace frbroo="http://iflastandards.info/ns/fr/frbr/frbroo/" ;
declare namespace hbasp="http://bahrschnitzler.acdh.oeaw.ac.at/property/";


declare variable $lod:additonal_data-root := $config:app-root || "/additional_data";

(:~ Returns data on a person as RDF :)
declare function lod:person($id as xs:string) {
    
        let $data := collection($config:data-root)/id($id)
        
        let $forename := $data//tei:forename
        let $surname := $data//tei:surname
        let $gnd := if ($data//tei:idno[@type='GND']/text()) then "http://d-nb.info/gnd/" || $data//tei:idno[@type='GND']/text() else ""

        
        let $label := $surname || ", " || $forename
        
        return
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}">
            <rdf:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E21_Person"/>
            <rdfs:label>{$label}</rdfs:label>
            
            <crm:P1_is_identified_by>
                <crm:E41_Appellation>
                    <rdfs:label xml:lang="de">{$label}</rdfs:label>
                </crm:E41_Appellation>
            </crm:P1_is_identified_by>
            
            
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>
            <owl:sameAs rdf:resource="{$gnd}"/>
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
    let $wienwiki := for $string in $additional_data//tei:idno[@subtype="WIENWIKI"]/string() return normalize-space($string)
     return
         
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}">
            <rdf:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E53_Place"/>
            
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
    
    let $hbassortDate := <hbasp:SortDate rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{api:DocSortDate($id)}</hbasp:SortDate>
    
    let $creation := local:generateCreationActivities($id)
    
    let $corresp-events := if (substring($id,1,1) eq "L") then lod:getCorrespondenceEvents($id) else ()
    
    (: try to get identifier of theatermuseum :)
    let $theatermuseum := try {if ($data//tei:listWit[1]/tei:msIdentifier/tei:repository[contains(.,"Theatermuseum")]) then 
        local:getTheatermuseumID($id) else ()} catch * {()}
    
    (: mentions :)
    let $mentions := lod:getMentions($id)
    
    (: Schnitzlertagebuch :)
    let $stb := if (substring($id,1,1) eq "D" ) then local:getTagebuch($id) else () 
    
    return 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}">
            {
                
            (
            <rdf:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E73_Information_Object"/>,
            $labels ,
            $creation ,
            $corresp-events ,
            (: $date, :)
            $hbassortDate ,
            <crm:P2_has_type rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/type/{substring($id,1,1)}"/> ,
            <crm:P2_has_type rdf:resource="{$doctype}"/>, 
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>,
            $theatermuseum ,
            $stb ,
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
        
        (: let $keys := tokenize(collection($config:data-root)/id($id)//tei:body//element()[@key]/@key/string(),' ')
        
        for $key in distinct-values($keys) :)
        return
            if (not(contains($key,' '))) then
            <schema:mentions xmlns:schema="http://schema.org/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$key}"/>
            else
                for  $distinct-key in tokenize($key,' ') return
                    <schema:mentions xmlns:schema="http://schema.org/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$distinct-key}"/>
   

else
    ()
};


(:~ Get the URI of a Document-Type :)
declare function local:getDocumentTypeURI($id) {
    (: http://bahrschnitzler.acdh.oeaw.ac.at/type/ :)
    (: perform a lookup in titleList 2DO:)
    
    
    let $sigla := substring($id, 1,1) 
    let $doc := collection($config:data-root)/id($id)
    let $type_in_openrefine := collection($lod:additonal_data-root)/id("openrefine")//row[contains(./id/text(),$id)]
        
    let $uri := "http://bahrschnitzler.acdh.oeaw.ac.at/type/" || $type_in_openrefine/type/string()
    
    
    return 
        $uri
};


declare function local:generateCreationActivities($id) {
    
    <crm:P94i_was_created_by xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/">
      <crm:E65_Creation>
        { 
            for $creator in local:getAuthorsOfDoc($id) return 
                <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$creator}"/>
        }
        { (:
            let $date := api:DocSortDate($id)
            return
                <crm:P4_has_time-span>
                        <crm:E52_Time-Span>
                            <crm:P82a_begin_of_the_begin rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date}</crm:P82a_begin_of_the_begin>
                            <crm:P82b_end_of_the_end rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date}</crm:P82b_end_of_the_end>
                        </crm:E52_Time-Span>
                </crm:P4_has_time-span>
            :)
            
            ()
                
        }
      </crm:E65_Creation>
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
                        <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$sender}"/>
                }
                {
                    for $place in $placeSender return
                        <crm:P7_took_place_at rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$place}"/>
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
                        <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$addressee}"/>
                }
                {
                    for $place in $placeAddressee return
                        <crm:P7_took_place_at rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$place}"/>
                }
            </crm:E7_Activity>
        </crm:P12i_was_present_at>
        
        
        )
};

declare function local:getTheatermuseumID($id as xs:string) {
    let $signatur := collection($config:data-root)/id($id)//tei:msIdentifier[contains(./tei:repository,'Theatermuseum')]/tei:idno/string()
    let $tm-query-id := "HS_" || replace(substring-after($signatur,'HS '),' ','')
    let $request-url := "https://www.theatermuseum.at/onlinesammlung/?rand=3&amp;extended=1&amp;id=11694&amp;L=0&amp;ext[object_number]=HS_AM23337Ba&amp;ext[dated-from-acad]=ad&amp;ext[dated-to-acad]=ad&amp;view=0&amp;type=686&amp;no_cache=1&amp;jsrand=0.7411997926468572"
    let $request := <http:request href="{$request-url}" method="GET"/>
    let $response := try { http:send-request($request) } catch * { () }
    
    let $theatermuseum-uri := substring-before($response[2]//element()[@id="object-list"]//element()[@data-id][1]/@href/string(),'/?offset')
    (: let $tm-query-string := xmldb:encode-uri("&amp;") :)
    
    (: try to get permalink :)
    let $request2 := <http:request href="{$theatermuseum-uri}" method="GET"/>
    let $permalink := try { http:send-request($request2)[2]//element()[@class="permalink"]//element()[@href]/@href/string() } catch * { () }
    let $perma-uri := substring($permalink, 1 , string-length($permalink)-1) 
    
    let $theatermuseum-identifier := <crm:P1_is_identified_by>
                                            <rdf:Description>
                                                <crm:E42_Identifier>{$signatur}</crm:E42_Identifier>
                                            </rdf:Description>
                                    </crm:P1_is_identified_by>
    
    (:  hier gibt's Probleme: <crm:P1_is_identified_by>
                                        <rdf:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E42_Identifier"/>
                                        <rdfs:label>{$signatur}</rdfs:label>
                                    </crm:P1_is_identified_by> :) 
        
    
    return
        (: <crm:P1_is_identified_by rdf:resource="{$tm-uri}"/> :)
        ( 
            if ( $theatermuseum-uri ) then <rdfs:seeAlso rdf:resource="{$theatermuseum-uri}"/> else () ,
            $theatermuseum-identifier ,
            if ( $theatermuseum-uri ) then <owl:sameAs rdf:resource="{$perma-uri}"/> else ()
        )
};

declare function local:getTagebuch($id as xs:string) {
    let $openrefine := collection($lod:additonal_data-root)/id("openrefine")//row[contains(./id/text(),$id)]
    return
        if ($openrefine/STB != "") then
            ( 
                <owl:sameAs rdf:resource="{$openrefine/ARCHE_id/text()}"/> 
            )
            else ()
};

(:~ Outputs data of an Institution CIDOC-like :)
declare function lod:institution($id) {
    (: some work has to be done, e.g. location in the TEI File is not rendered, but there has to be the Information added :)
    let $data := collection($config:data-root)/id($id)
    let $labels := for $label in $data/tei:orgName/text() return <rdfs:label>{$label}</rdfs:label>
    let $entitytype := if ($data/@type) then "http://bahrschnitzler.acdh.oeaw.ac.at/type/" || $data/@type else  () (: replace($data/tei:desc/string(),' ','_')  :)
    return
        
        if ($data/tei:orgName != "") then
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}">
            {
            (
            <rdf:type rdf:resource="http://www.cidoc-crm.org/cidoc-crm/E1_CRM_Entity"/>,
            $labels ,
            <crm:P1_is_identified_by>
                <crm:E41_Appellation>
                    <rdfs:label xml:lang="de">{$labels/text()}</rdfs:label>
                </crm:E41_Appellation>
            </crm:P1_is_identified_by> ,
            if ($data/@type) then <crm:P2_has_type rdf:resource="{$entitytype}"/> else (), 
            <crm:P1_is_identified_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/id/{$id}"/>
            (:,$data:)
            )
                
            }
        </rdf:Description>
        else ()
};

(:~ Create frbr works :)
declare function lod:work($id) {
    let $data := collection($config:data-root)/id($id)
    let $authors_for_labels := for $author in $data/tei:titleStmt/tei:author  return $author//tei:persName/tei:forename ||  " " || $author/tei:persName/tei:surname 
    let $labels := for $label in $data/tei:titleStmt/tei:title return
        <rdfs:label>{$label/text() || ' [Werk von ' || string-join($authors_for_labels,';') || ']'  }</rdfs:label>
    
    (: zusätzliche ids :)
    let $frbroo_F27id := util:uuid() (: has to be stored somewhere :)
    let $frbroo_F28id := util:uuid()
    let $frbroo_F30id := util:uuid()
    
    
    (: Work :)
    let $frbroo_F1 :=
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}">
              <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F1_Work"/>
              {
                  $labels
              }
              {(: <frbroo:R3_is_realised_in rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F2"/> :) ()}
              <frbroo:R16i_was_initiated_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F27id}"/> {(: Konzeptionierungsevent :)()}
              <frbroo:R19i_was_realised_through rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F28id}"/> {(: Expression creation event :)()}
              <frbroo:R40_has_representative_expression rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F22"/> {(: verknüpft mit der repräsentativen expression F22 :) ()}
        </rdf:Description>
        
    (: Expression :)
    (: will remove this for now and replace with f22 :)
    (: let $frbroo_F2 :=
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F2">
              <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F2_Expression"/>
              <rdfs:label xml:lang="de">F2 Expression zu F1 Werk {$data/tei:titleStmt/tei:title/text()} [{$id}]</rdfs:label>
              <frbroo:R3i_realises rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}"/>
              <frbroo:R17i_was_created_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F28id}"/>
        </rdf:Description> 
        :)
    
    (: F22 Self Contained Expression :)
    (: Der Unterschied zwischen Expression und Self Contained Expression ist mir nicht ganz klar :)
    let $frbroo_F22 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F22">
            <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F22_Self_Contained_Expression"/>
            <rdfs:label>Repräsentative Expression zu {$data/tei:titleStmt/tei:title/text()}</rdfs:label>
            <frbroo:R40i_is_representative_expression_for rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}"/>
            {
                (: möglicherweise könnte man hier das Expression Creation Event verwenden; das hatte ich vorher für die Expression :)
                <frbroo:R17i_was_created_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F28id}"/>
            }
            <frbroo:R4_carriers_provided_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F3"/>
            
        </rdf:Description>
    
    
    (: Aktivität, durch die das Werk entwickelt wird :)   
    let $frbroo_F27 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F27id}">
              <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F27_Work_Conception"/>
              <rdfs:label xml:lang="de">Konzeptionierungsphase zu {$data/tei:titleStmt/tei:title/text()} [{$id}]</rdfs:label>
                {
                    for $creator in $data/tei:titleStmt/tei:author
                    return
                        <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{substring-after($creator/@ref,'#')}"/>
                }
                <frbroo:R16_initiated rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}"/>
        </rdf:Description>
    
    (: Expression Creation event :)
    (: hab ich vorher für F2 verwendet, jetzt für die Repräsentative Expression F22 :)
    let $frbroo_F28 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F28id}">
            <rdfs:typ rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F28_Expression_Creation"/>
            <rdfs:label xml:lang="de">Aktivität, die die repräsentative F22 Self Contained Expression zu {$data/tei:titleStmt/tei:title/text()} [{$id}] hervorgebracht hat</rdfs:label>
            <frbroo:R19_created_a_realization_of rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}"/>
            {
                for $creator in $data/tei:titleStmt/tei:author
                return
                    <crm:P14_carried_out_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{substring-after($creator/@ref,'#')}"/>
            }
            {(: <frbroo:R17_created rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/A020000_F2"/>:) (: die hab ich rausgenommen, stattdessen F22:) ()}
            {
                (: Möglicherweise könnte man auf die F2 verzichten, wenn man hier die F22 reinnimmt frbroo:R17_created :)
                <frbroo:R17_created rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F22"/>
            }
        </rdf:Description>
        
        (: Manifestation Product Type :)
    let $frbroo_F3 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F3">
            <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F3_Manifestation_Product_Type"/>
            <rdfs:label>Manifestation Product Type zu {$data/tei:titleStmt/tei:title/text()} [{$id}]</rdfs:label>
            {() (: <!-- könnte einen type haben --> :)}
            <frbroo:R4i_comprises_carriers_of rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F22"/>
            <frbroo:CLR6_should_carry rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F24"/>
            {
                if ( $data/tei:notesStmt/tei:note and contains($data/tei:notesStmt/tei:note/text(),'http')) then
                    <rdfs:seeAlso rdf:resource="{$data/tei:notesStmt/tei:note/text()}"/>
                    else ()
            }
        </rdf:Description>
    
    (: Publication event :)
    let $frbroo_F30 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F30id}">
            <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F30_Publication_Event"/>
            <rdfs:label xml:lang="de">Publikation von {normalize-space($data/tei:titleStmt/tei:title/text())} [{$id}] in: {$data/tei:publicationStmt/tei:ab[@type="Bibliografie"]/text()}</rdfs:label>
            {() (: <!-- carried out by Verlag http://www.cidoc-crm.org/cidoc-crm/P14_carried_out_by --> :)}
            {(:Zeit als timespan:)
            let $date_unstructured := $data/tei:publicationStmt/tei:ab[@type="Erscheinungsdatum"]/text()
            let $from-to := if ( matches($date_unstructured,'^\d+\.\s\d+\.\s\d{4}\s–\s\d+\.\s\d+\.\s\d{4}$') ) then
                let $from := 
                    let $date-part:= tokenize($date_unstructured,' – ')[1]
                    let $yyyy := tokenize($date-part,' ')[3]
                    let $mm := format-number(number(substring-before(tokenize($date-part,' ')[2],'.')),'00')
                    let $dd := format-number(number(substring-before(tokenize($date-part,' ')[1],'.')),'00')
                    return $yyyy || "-" || string($mm) || "-" || $dd
                    
                let $to := 
                    let $date-part:= tokenize($date_unstructured,' – ')[2]
                    let $yyyy := tokenize($date-part,' ')[3]
                    let $mm := format-number(number(substring-before(tokenize($date-part,' ')[2],'.')),'00')
                    let $dd := format-number(number(substring-before(tokenize($date-part,' ')[1],'.')),'00')
                    return $yyyy || "-" || string($mm) || "-" || $dd
                    
                return
                    ($from, $to)
                else ""
            let $date_iso := if (matches($date_unstructured,"\d+\.\s\d+\.\s\d{4}")) then 
                let $yyyy := tokenize($date_unstructured,' ')[3]
                let $mm := format-number(number(substring-before(tokenize($date_unstructured,' ')[2],'.')),'00')
                let $dd := format-number(number(substring-before(tokenize($date_unstructured,' ')[1],'.')),'00')
                return $yyyy || "-" || string($mm) || "-" || string($dd)
                else $date_unstructured
            return
                <crm:P4_has_time-span>
                    <crm:E52_Time-Span>
                        {
                            if ( matches($date_unstructured,"^\d+\.\s\d+\.\s\d{4}$") ) then
                                (
                        <crm:P82a_begin_of_the_begin rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date_iso}</crm:P82a_begin_of_the_begin> ,
                        <crm:P82b_end_of_the_end rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date_iso}</crm:P82b_end_of_the_end>
                                )
                        else if ( matches($date_unstructured,"^\d{4}$")  ) then 
                            <crm:P86_falls_within>
                                <crm:E52_Time-Span>
                                    <crm:P82a_begin_of_the_begin rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date_unstructured}-01-01</crm:P82a_begin_of_the_begin> 
                                    <crm:P82b_end_of_the_end rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$date_unstructured}-12-31</crm:P82b_end_of_the_end>
                                </crm:E52_Time-Span>
                            </crm:P86_falls_within>
                        
                        else if ( matches($date_unstructured,'^\d+\.\s\d+\.\s\d{4}\s–\s\d+\.\s\d+\.\s\d{4}$') )  then
                            (
                            <crm:P82a_begin_of_the_begin rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$from-to[1]}</crm:P82a_begin_of_the_begin> ,
                            <crm:P82b_end_of_the_end rdf:datatype="http://www.w3.org/2001/XMLSchema#date">{$from-to[2]}</crm:P82b_end_of_the_end>
                            )    
                            
                        else ()
                        }
                    </crm:E52_Time-Span>
                </crm:P4_has_time-span>
            }
            
            {() (: <!-- Ort  <crm:P7_took_place_at />--> :)}
            <frbroo:R24_created rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F24"/>
        </rdf:Description>
   
    (: Publication Expression :)
    let $frbroo_F24 := 
        <rdf:Description rdf:about="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F24">
            <rdf:type rdf:resource="http://iflastandards.info/ns/fr/frbr/frbroo/F24_Publication_Expression"/>
            <rdfs:label xml:lang="de">Publication Expression zu {normalize-space($data/tei:titleStmt/tei:title/text())}</rdfs:label>
            <frbroo:R24i_was_created_through rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$frbroo_F30id}"/>
            <frbroo:CLR6i_should_be_carried_by rdf:resource="http://bahrschnitzler.acdh.oeaw.ac.at/entity/{$id}_F3"/>
        </rdf:Description>
    
        
    return
        (
        $frbroo_F1 (: F1 Werk; das ist das, auf das in den Annotationen verwiesen wird :) , 
        (: $frbroo_F2 , :) (: F2 Expression; hier ist unklar, ob man nicht eine F22 Self Contained Expression ansetzen muss :)
        $frbroo_F22 , (: Repräsentative Expression zum Werk :)
        $frbroo_F27, (: Konzeptionierungsevent zum Werk; http://iflastandards.info/ns/fr/frbr/frbroo/F27_Work_Conception :)
        $frbroo_F28 , (: Realisierungsaktivität macht aus einem Werk eine Expression :)
        $frbroo_F3 (: Manifestation Product Type :) ,
        $frbroo_F30 (: Publication Event :),
        $frbroo_F24 (: Publication Expression:) 
        (: ,
        $data
        :)
        )
};

(:~ :)
declare function lod:dumpRDF() {

  let $diaries := for $D-id in collection($config:data-root || "/diaries")//tei:TEI/@xml:id/string()
    return lod:resource($D-id)


let $letters := for $L-id in collection($config:data-root || "/letters")//tei:TEI/@xml:id/string()
    return lod:resource($L-id)

let $texts := for $T-id in collection($config:data-root || "/letters")//tei:TEI/@xml:id/string()
    return lod:resource($T-id)

let $persons := for $P-id in collection($config:data-root || "/meta/Personen.xml")//tei:person/@xml:id/string()
    return lod:person($P-id)

let $places := for $Pl-id in collection($config:data-root || "/meta/Orte.xml")//tei:place/@xml:id/string()
    return lod:place($Pl-id)

let $institutions := for $I-id in collection($config:data-root || "/meta/Organisationen.xml")//tei:org/@xml:id/string()
    return lod:institution($I-id)

let $works := for $W-id in collection($config:data-root || "/meta/Werke.xml")//tei:biblFull/@xml:id/string()
    return lod:work($W-id)
    
let $RDF :=    
    
    <rdf:RDF 
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/"
    xmlns:schema="http://schema.org/"
    xmlns:dct="http://purl.org/dc/terms/"
    xmlns:frbroo="http://iflastandards.info/ns/fr/frbr/frbroo/"
    xmlns:hbasp="http://bahrschnitzler.acdh.oeaw.ac.at/property/"
>

{
    ( 
       $diaries ,
        $letters,
        $texts ,
        $persons ,
        $places ,
        $institutions ,
        $works
    )
}

</rdf:RDF>

let $filename := "hbas_letters.rdf"
let $location := $config:app-root || "/export"
let $saved := xmldb:store($location, $filename, $RDF)
 
    
    return 
        
        "Exported RDF to " || $filename || "at " || $location 
        
};

(:~ :)
declare function lod:dumpTypeRDF($type) {
let $data := switch ($type)
    
    case "diaries" return 
        for $D-id in collection($config:data-root || "/diaries")//tei:TEI/@xml:id/string()
            return lod:resource($D-id)


case "letters" return for $L-id in collection($config:data-root || "/letters")//tei:TEI/@xml:id/string()
    return lod:resource($L-id)

case "texts" return for $T-id in collection($config:data-root || "/texts")//tei:TEI/@xml:id/string()
    return lod:resource($T-id)

case "persons" return for $P-id in collection($config:data-root || "/meta")/id("Personen")//tei:person/@xml:id/string()
    return lod:person($P-id)

case "places" return  for $Pl-id in collection($config:data-root || "/meta")/id("Orte")//tei:place/@xml:id/string()
    return lod:place($Pl-id)

case "institutions" return  for $I-id in collection($config:data-root || "/meta")/id("Organisationen")//tei:org/@xml:id/string()
    return lod:institution($I-id)

case "works" return  for $W-id in collection($config:data-root || "/meta")//id("Werke")//tei:biblFull/@xml:id/string()
    return lod:work($W-id)


default return ()
    
let $RDF :=    
    
    <rdf:RDF 
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:owl="http://www.w3.org/2002/07/owl#"
    xmlns:crm="http://www.cidoc-crm.org/cidoc-crm/"
    xmlns:schema="http://schema.org/"
    xmlns:dct="http://purl.org/dc/terms/"
    xmlns:frbroo="http://iflastandards.info/ns/fr/frbr/frbroo/"
    xmlns:hbasp="http://bahrschnitzler.acdh.oeaw.ac.at/property/"
>

{
    $data
}

</rdf:RDF>

let $filename := "hbas_" || $type || ".rdf"
let $location := $config:app-root || "/export"
let $saved := xmldb:store($location, $filename, $RDF)
 
    
    return 
        
        "Exported RDF to " || $filename || "at " || $location 
        
};

