--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: fhir; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA fhir;


SET search_path = fhir, pg_catalog;

--
-- Name: AddressUse; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "AddressUse" AS ENUM (
    'home',
    'work',
    'temp',
    'old'
);


--
-- Name: ContactSystem; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "ContactSystem" AS ENUM (
    'url',
    'email',
    'fax',
    'phone'
);


--
-- Name: ContactUse; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "ContactUse" AS ENUM (
    'old',
    'temp',
    'work',
    'home',
    'mobile'
);


--
-- Name: DocumentReferenceStatus; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "DocumentReferenceStatus" AS ENUM (
    'current',
    'superceded',
    'entered in error'
);


--
-- Name: EventTiming; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "EventTiming" AS ENUM (
    'PCD',
    'HS',
    'WAKE',
    'AC',
    'ACM',
    'ACD',
    'ACV',
    'PC',
    'PCV',
    'PCM'
);


--
-- Name: IdentifierUse; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "IdentifierUse" AS ENUM (
    'temp',
    'secondary',
    'official',
    'usual'
);


--
-- Name: NameUse; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "NameUse" AS ENUM (
    'nickname',
    'anonymous',
    'old',
    'maiden',
    'usual',
    'official',
    'temp'
);


--
-- Name: NarrativeStatus; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "NarrativeStatus" AS ENUM (
    'extensions',
    'empty',
    'generated',
    'additional'
);


--
-- Name: QuantityCompararator; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "QuantityCompararator" AS ENUM (
    '&gt;',
    '&lt;',
    '&lt;=',
    '&gt;='
);


--
-- Name: ResourceType; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "ResourceType" AS ENUM (
    'Organization',
    'ImagingStudy',
    'DiagnosticOrder',
    'Alert',
    'OrderResponse',
    'Specimen',
    'RelatedPerson',
    'MessageHeader',
    'Medication',
    'ValueSet',
    'Group',
    'DiagnosticReport',
    'Substance',
    'Procedure',
    'AdverseReaction',
    'Order',
    'Query',
    'Device',
    'Supply',
    'CarePlan',
    'Condition',
    'ConceptMap',
    'Patient',
    'Practitioner',
    'Provenance',
    'Immunization',
    'DocumentReference',
    'AllergyIntolerance',
    'Observation',
    'Location',
    'Profile',
    'Other',
    'FamilyHistory',
    'Media',
    'Conformance',
    'OperationOutcome',
    'DeviceObservationReport',
    'Composition',
    'Questionnaire',
    'List',
    'MedicationStatement',
    'SecurityEvent',
    'Encounter',
    'MedicationAdministration',
    'MedicationPrescription',
    'MedicationDispense',
    'DocumentManifest',
    'ImmunizationRecommendation'
);


--
-- Name: SearchParamType; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "SearchParamType" AS ENUM (
    'token',
    'date',
    'string',
    'reference',
    'composite',
    'quantity',
    'number'
);


--
-- Name: UnitsOfTime; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "UnitsOfTime" AS ENUM (
    'wk',
    's',
    'min',
    'h',
    'd',
    'mo',
    'a'
);


--
-- Name: ValueSetStatus; Type: TYPE; Schema: fhir; Owner: -
--

CREATE TYPE "ValueSetStatus" AS ENUM (
    'draft',
    'retired',
    'active'
);


--
-- Name: insert_resource(json); Type: FUNCTION; Schema: fhir; Owner: -
--

CREATE FUNCTION insert_resource(jdata json) RETURNS uuid
    LANGUAGE plpythonu
    AS $$
  import json
  import re

  def walk(parents, name, obj, cb):
    res = cb(parents, name, obj)
    new_parents = list(parents)
    new_parents.append({'name': name, 'obj': obj, 'meta': res})
    for key, value in obj.items():
      if isinstance(value, dict):
        walk(new_parents, key, value, cb)
      elif isinstance(value, list):
        def walk_through_list(elem):
          if isinstance(elem, dict):
            walk(new_parents, key, elem, cb)
        map(walk_through_list, value)

  def walk_function(parents, name, obj):
    pth = map(lambda x: underscore(x['name']), parents)
    pth.append(name)
    table_name = get_table_name(pth)

    if table_exists(table_name):
      attrs = collect_attributes(table_name, obj)
      if len(parents) > 1 and 'parent_id' not in attrs:
        attrs['parent_id'] = parents[-1]['meta']
      if len(parents) > 0:
        if 'parent_id' not in attrs:
          attrs['parent_id'] = parents[0]['meta']
        if 'resource_id' not in attrs:
          attrs['resource_id'] = parents[0]['meta']

      if 'id' not in attrs:
        attrs['id'] = uuid()

      insert_record('fhir', table_name, attrs)
      return attrs['id']
    else:
      log('Skip %s with path %s' % (table_name, pth))

  def insert_record(schema, table_name, attrs):
    attrs['_type'] = table_name
    query = """
      INSERT INTO %(schema)s.%(table)s
      SELECT * FROM json_populate_recordset(null::%(schema)s.%(table)s, '%(json)s'::json)
    """ % { 'schema': schema, 'table': table_name, 'json': json.dumps([attrs]) }
    plpy.execute(query)

  def uuid():
    sql = 'select uuid_generate_v4() as uuid'
    return plpy.execute(sql)[0]['uuid']

  # http://inflection.readthedocs.org/en/latest/_modules/inflection.html#camelize
  def camelize(string, uppercase_first_letter=True):
    if uppercase_first_letter:
      return re.sub(r"(?:^|_)(.)", lambda m: m.group(1).upper(), string)
    else:
      return string[0].lower() + camelize(string)[1:]

  # http://inflection.readthedocs.org/en/latest/_modules/inflection.html#underscore
  def underscore(word):
    word = re.sub(r"([A-Z]+)([A-Z][a-z])", r'\1_\2', word)
    word = re.sub(r"([a-z\d])([A-Z])", r'\1_\2', word)
    word = word.replace("-", "_")
    return word.lower()

  def get_table_name(path):
    args = ','.join(map(lambda e: plpy.quote_literal(e), path))
    sql = 'SELECT table_name(ARRAY[%s])' % args
    return plpy.execute(sql)[0]['table_name']

  def table_exists(table_name):
    query =  """
      select table_name
      from information_schema.tables
      where table_schema = 'fhir'
      """
    if not('table_names' in SD):
      SD['table_names'] = map(lambda d: d['table_name'], plpy.execute(query))

    return table_name in SD['table_names']

  def log(x):
    plpy.notice(x)

  def get_columns(table_name):
    if not('columns' in SD):
      query = """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'fhir'
      """
      def reduce_function(acc, value):
        key = value['table_name']
        if key not in acc:
          acc[key] = set([])
        acc[key].add(value['column_name'])
        return acc

      SD['columns'] = reduce(reduce_function, plpy.execute(query), {})
    return SD['columns'][table_name]

  def collect_attributes(table_name, obj):
    #TODO: quote literal
    def arr2lit(v):
      return '{%s}' % ','.join(map(lambda e: '"%s"' % e, v))

    columns = get_columns(table_name)
    def is_column(k):
      return k in columns

    def is_unknown_attribute(v):
      return not(isinstance(v, dict) or isinstance(v, list))

    def coerce(v):
      if isinstance(v, list):
        return arr2lit(v)
      else:
        return v;

    attrs = {}
    for k, v in obj.items():
      key = underscore(k)
      if is_column(key):
        attrs[key] = coerce(v)
      elif is_unknown_attribute(v):
        if '_unknown_attributes' not in attrs:
          attrs['_unknown_attributes'] = {}
        attrs['_unknown_attributes'][k] = coerce(v)
    if '_unknown_attributes' in attrs:
      attrs['_unknown_attributes'] = json.dumps(attrs['_unknown_attributes'])
    return attrs


  data = json.loads(jdata)
  if 'id' not in data:
    data['id'] = uuid()
  walk([], underscore(data['resourceType']), data, walk_function)
  return data['id']
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: resource_component; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource_component (
    id uuid NOT NULL,
    _type character varying NOT NULL,
    _unknown_attributes json,
    parent_id uuid NOT NULL,
    resource_id uuid NOT NULL,
    container_id uuid
);


--
-- Name: address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE address (
    use "AddressUse",
    text character varying,
    line character varying[],
    city character varying,
    state character varying,
    zip character varying,
    country character varying
)
INHERITS (resource_component);


--
-- Name: period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE period (
    start timestamp without time zone,
    "end" timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE address_period (
)
INHERITS (period);


--
-- Name: resource; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource (
    id uuid NOT NULL,
    _type character varying NOT NULL,
    _unknown_attributes json,
    resource_type character varying,
    language character varying,
    container_id uuid
);


--
-- Name: adverse_reaction; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction (
    did_not_occur_flag boolean NOT NULL,
    date timestamp without time zone
)
INHERITS (resource);


--
-- Name: adverse_reaction_exposure; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_exposure (
    causality_expectation character varying,
    type character varying,
    date timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: resource_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE resource_reference (
    reference character varying,
    display character varying
)
INHERITS (resource_component);


--
-- Name: adverse_reaction_exposure_substance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_exposure_substance (
)
INHERITS (resource_reference);


--
-- Name: idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE idn (
    use "IdentifierUse",
    label character varying,
    system character varying,
    value character varying
)
INHERITS (resource_component);


--
-- Name: adverse_reaction_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_idn (
)
INHERITS (idn);


--
-- Name: idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE idn_assigner (
)
INHERITS (resource_reference);


--
-- Name: adverse_reaction_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE idn_period (
)
INHERITS (period);


--
-- Name: adverse_reaction_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_idn_period (
)
INHERITS (idn_period);


--
-- Name: adverse_reaction_recorder; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_recorder (
)
INHERITS (resource_reference);


--
-- Name: adverse_reaction_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_subject (
)
INHERITS (resource_reference);


--
-- Name: adverse_reaction_symptom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_symptom (
    severity character varying
)
INHERITS (resource_component);


--
-- Name: cc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE cc (
    text character varying
)
INHERITS (resource_component);


--
-- Name: adverse_reaction_symptom_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_symptom_code (
)
INHERITS (cc);


--
-- Name: cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE cd (
    system character varying,
    version character varying,
    code character varying,
    display character varying,
    "primary" boolean
)
INHERITS (resource_component);


--
-- Name: cc_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE cc_cd (
)
INHERITS (cd);


--
-- Name: adverse_reaction_symptom_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_symptom_code_cd (
)
INHERITS (cc_cd);


--
-- Name: cc_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE cc_cd_vs (
)
INHERITS (resource_reference);


--
-- Name: adverse_reaction_symptom_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_symptom_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: narrative; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE narrative (
    status "NarrativeStatus" NOT NULL,
    div text NOT NULL
)
INHERITS (resource_component);


--
-- Name: adverse_reaction_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE adverse_reaction_text (
)
INHERITS (narrative);


--
-- Name: alert; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert (
    status character varying NOT NULL,
    note character varying NOT NULL
)
INHERITS (resource);


--
-- Name: alert_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_author (
)
INHERITS (resource_reference);


--
-- Name: alert_category; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_category (
)
INHERITS (cc);


--
-- Name: alert_category_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_category_cd (
)
INHERITS (cc_cd);


--
-- Name: alert_category_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_category_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: alert_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_idn (
)
INHERITS (idn);


--
-- Name: alert_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: alert_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_idn_period (
)
INHERITS (idn_period);


--
-- Name: alert_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_subject (
)
INHERITS (resource_reference);


--
-- Name: alert_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE alert_text (
)
INHERITS (narrative);


--
-- Name: allergy_intolerance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance (
    status character varying NOT NULL,
    sensitivity_type character varying NOT NULL,
    criticality character varying,
    recorded_date timestamp without time zone
)
INHERITS (resource);


--
-- Name: allergy_intolerance_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_idn (
)
INHERITS (idn);


--
-- Name: allergy_intolerance_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: allergy_intolerance_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_idn_period (
)
INHERITS (idn_period);


--
-- Name: allergy_intolerance_reaction; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_reaction (
)
INHERITS (resource_reference);


--
-- Name: allergy_intolerance_recorder; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_recorder (
)
INHERITS (resource_reference);


--
-- Name: allergy_intolerance_sensitivity_test; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_sensitivity_test (
)
INHERITS (resource_reference);


--
-- Name: allergy_intolerance_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_subject (
)
INHERITS (resource_reference);


--
-- Name: allergy_intolerance_substance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_substance (
)
INHERITS (resource_reference);


--
-- Name: allergy_intolerance_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE allergy_intolerance_text (
)
INHERITS (narrative);


--
-- Name: attachment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE attachment (
    content_type character varying NOT NULL,
    language character varying,
    data bytea,
    url character varying,
    size integer,
    hash bytea,
    title character varying
)
INHERITS (resource_component);


--
-- Name: care_plan; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan (
    status character varying NOT NULL,
    modified timestamp without time zone,
    notes character varying
)
INHERITS (resource);


--
-- Name: care_plan_activity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity (
    prohibited boolean NOT NULL,
    status character varying,
    notes character varying
)
INHERITS (resource_component);


--
-- Name: care_plan_activity_action_resulting; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_action_resulting (
)
INHERITS (resource_reference);


--
-- Name: care_plan_activity_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_detail (
)
INHERITS (resource_reference);


--
-- Name: care_plan_activity_simple; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple (
    category character varying NOT NULL,
    timing_string character varying,
    details character varying
)
INHERITS (resource_component);


--
-- Name: care_plan_activity_simple_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_code (
)
INHERITS (cc);


--
-- Name: care_plan_activity_simple_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_code_cd (
)
INHERITS (cc_cd);


--
-- Name: care_plan_activity_simple_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE quantity (
    value numeric,
    comparator "QuantityCompararator",
    units character varying,
    system character varying,
    code character varying
)
INHERITS (resource_component);


--
-- Name: care_plan_activity_simple_daily_amount; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_daily_amount (
)
INHERITS (quantity);


--
-- Name: care_plan_activity_simple_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_loc (
)
INHERITS (resource_reference);


--
-- Name: care_plan_activity_simple_performer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_performer (
)
INHERITS (resource_reference);


--
-- Name: care_plan_activity_simple_product; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_product (
)
INHERITS (resource_reference);


--
-- Name: care_plan_activity_simple_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_quantity (
)
INHERITS (quantity);


--
-- Name: care_plan_activity_simple_timing_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_timing_period (
)
INHERITS (period);


--
-- Name: schedule; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE schedule (
)
INHERITS (resource_component);


--
-- Name: care_plan_activity_simple_timing_schedule; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_timing_schedule (
)
INHERITS (schedule);


--
-- Name: schedule_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE schedule_event (
)
INHERITS (period);


--
-- Name: care_plan_activity_simple_timing_schedule_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_timing_schedule_event (
)
INHERITS (schedule_event);


--
-- Name: schedulerepeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE schedulerepeat (
    frequency integer,
    "when" "EventTiming",
    duration numeric NOT NULL,
    units "UnitsOfTime" NOT NULL,
    count integer,
    "end" timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: schedule_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE schedule_repeat (
)
INHERITS (schedulerepeat);


--
-- Name: care_plan_activity_simple_timing_schedule_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_activity_simple_timing_schedule_repeat (
)
INHERITS (schedule_repeat);


--
-- Name: care_plan_concern; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_concern (
)
INHERITS (resource_reference);


--
-- Name: care_plan_goal; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_goal (
    status character varying,
    notes character varying,
    description character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: care_plan_goal_concern; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_goal_concern (
)
INHERITS (resource_reference);


--
-- Name: care_plan_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_idn (
)
INHERITS (idn);


--
-- Name: care_plan_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: care_plan_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_idn_period (
)
INHERITS (idn_period);


--
-- Name: care_plan_participant; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_participant (
)
INHERITS (resource_component);


--
-- Name: care_plan_participant_member; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_participant_member (
)
INHERITS (resource_reference);


--
-- Name: care_plan_participant_role; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_participant_role (
)
INHERITS (cc);


--
-- Name: care_plan_participant_role_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_participant_role_cd (
)
INHERITS (cc_cd);


--
-- Name: care_plan_participant_role_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_participant_role_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: care_plan_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_patient (
)
INHERITS (resource_reference);


--
-- Name: care_plan_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_period (
)
INHERITS (period);


--
-- Name: care_plan_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE care_plan_text (
)
INHERITS (narrative);


--
-- Name: cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE cd_vs (
)
INHERITS (resource_reference);


--
-- Name: composition; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition (
    status character varying NOT NULL,
    date timestamp without time zone NOT NULL,
    title character varying
)
INHERITS (resource);


--
-- Name: composition_attester; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_attester (
    mode character varying[] NOT NULL,
    "time" timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: composition_attester_party; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_attester_party (
)
INHERITS (resource_reference);


--
-- Name: composition_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_author (
)
INHERITS (resource_reference);


--
-- Name: composition_class; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_class (
)
INHERITS (cc);


--
-- Name: composition_class_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_class_cd (
)
INHERITS (cc_cd);


--
-- Name: composition_class_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_class_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: composition_confidentiality; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_confidentiality (
)
INHERITS (cd);


--
-- Name: composition_confidentiality_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_confidentiality_vs (
)
INHERITS (cd_vs);


--
-- Name: composition_custodian; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_custodian (
)
INHERITS (resource_reference);


--
-- Name: composition_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_encounter (
)
INHERITS (resource_reference);


--
-- Name: composition_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event (
)
INHERITS (resource_component);


--
-- Name: composition_event_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event_code (
)
INHERITS (cc);


--
-- Name: composition_event_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event_code_cd (
)
INHERITS (cc_cd);


--
-- Name: composition_event_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: composition_event_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event_detail (
)
INHERITS (resource_reference);


--
-- Name: composition_event_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_event_period (
)
INHERITS (period);


--
-- Name: composition_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_idn (
)
INHERITS (idn);


--
-- Name: composition_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: composition_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_idn_period (
)
INHERITS (idn_period);


--
-- Name: composition_section; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section (
    title character varying
)
INHERITS (resource_component);


--
-- Name: composition_section_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section_code (
)
INHERITS (cc);


--
-- Name: composition_section_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section_code_cd (
)
INHERITS (cc_cd);


--
-- Name: composition_section_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: composition_section_content; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section_content (
)
INHERITS (resource_reference);


--
-- Name: composition_section_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_section_subject (
)
INHERITS (resource_reference);


--
-- Name: composition_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_subject (
)
INHERITS (resource_reference);


--
-- Name: composition_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_text (
)
INHERITS (narrative);


--
-- Name: composition_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_type (
)
INHERITS (cc);


--
-- Name: composition_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_type_cd (
)
INHERITS (cc_cd);


--
-- Name: composition_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE composition_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: concept_map; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map (
    experimental boolean,
    status character varying NOT NULL,
    date timestamp without time zone,
    copyright character varying,
    description character varying,
    publisher character varying,
    name character varying NOT NULL,
    version character varying,
    identifier character varying
)
INHERITS (resource);


--
-- Name: concept_map_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_concept (
    code character varying,
    system character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: concept_map_concept_depends_on; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_concept_depends_on (
    code character varying NOT NULL,
    concept character varying NOT NULL,
    system character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: concept_map_concept_map; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_concept_map (
    equivalence character varying NOT NULL,
    code character varying,
    comments character varying,
    system character varying
)
INHERITS (resource_component);


--
-- Name: concept_map_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_source (
)
INHERITS (resource_reference);


--
-- Name: concept_map_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_target (
)
INHERITS (resource_reference);


--
-- Name: contact; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE contact (
    system "ContactSystem",
    value character varying,
    use "ContactUse"
)
INHERITS (resource_component);


--
-- Name: concept_map_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_telecom (
)
INHERITS (contact);


--
-- Name: contact_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE contact_period (
)
INHERITS (period);


--
-- Name: concept_map_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_telecom_period (
)
INHERITS (contact_period);


--
-- Name: concept_map_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE concept_map_text (
)
INHERITS (narrative);


--
-- Name: condition; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition (
    abatement_boolean boolean,
    status character varying NOT NULL,
    abatement_date date,
    onset_date date,
    date_asserted date,
    notes character varying
)
INHERITS (resource);


--
-- Name: condition_asserter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_asserter (
)
INHERITS (resource_reference);


--
-- Name: condition_category; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_category (
)
INHERITS (cc);


--
-- Name: condition_category_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_category_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_category_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_category_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_certainty; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_certainty (
)
INHERITS (cc);


--
-- Name: condition_certainty_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_certainty_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_certainty_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_certainty_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_code (
)
INHERITS (cc);


--
-- Name: condition_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_code_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_encounter (
)
INHERITS (resource_reference);


--
-- Name: condition_evidence; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_evidence (
)
INHERITS (resource_component);


--
-- Name: condition_evidence_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_evidence_code (
)
INHERITS (cc);


--
-- Name: condition_evidence_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_evidence_code_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_evidence_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_evidence_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_evidence_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_evidence_detail (
)
INHERITS (resource_reference);


--
-- Name: condition_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_idn (
)
INHERITS (idn);


--
-- Name: condition_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: condition_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_idn_period (
)
INHERITS (idn_period);


--
-- Name: condition_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_loc (
    detail character varying
)
INHERITS (resource_component);


--
-- Name: condition_loc_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_loc_code (
)
INHERITS (cc);


--
-- Name: condition_loc_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_loc_code_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_loc_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_loc_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_related_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_related_item (
    type character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: condition_related_item_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_related_item_code (
)
INHERITS (cc);


--
-- Name: condition_related_item_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_related_item_code_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_related_item_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_related_item_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_related_item_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_related_item_target (
)
INHERITS (resource_reference);


--
-- Name: condition_severity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_severity (
)
INHERITS (cc);


--
-- Name: condition_severity_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_severity_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_severity_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_severity_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_stage; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_stage (
)
INHERITS (resource_component);


--
-- Name: condition_stage_assessment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_stage_assessment (
)
INHERITS (resource_reference);


--
-- Name: condition_stage_summary; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_stage_summary (
)
INHERITS (cc);


--
-- Name: condition_stage_summary_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_stage_summary_cd (
)
INHERITS (cc_cd);


--
-- Name: condition_stage_summary_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_stage_summary_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: condition_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_subject (
)
INHERITS (resource_reference);


--
-- Name: condition_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE condition_text (
)
INHERITS (narrative);


--
-- Name: conformance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance (
    experimental boolean,
    accept_unknown boolean NOT NULL,
    status character varying,
    format character varying[] NOT NULL,
    date timestamp without time zone NOT NULL,
    fhir_version character varying NOT NULL,
    description character varying,
    publisher character varying NOT NULL,
    name character varying,
    version character varying,
    identifier character varying
)
INHERITS (resource);


--
-- Name: conformance_document; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_document (
    mode character varying NOT NULL,
    documentation character varying
)
INHERITS (resource_component);


--
-- Name: conformance_document_profile; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_document_profile (
)
INHERITS (resource_reference);


--
-- Name: conformance_implementation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_implementation (
    description character varying NOT NULL,
    url character varying
)
INHERITS (resource_component);


--
-- Name: conformance_messaging; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging (
    reliable_cache integer,
    documentation character varying,
    endpoint character varying
)
INHERITS (resource_component);


--
-- Name: conformance_messaging_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event (
    focus character varying NOT NULL,
    mode character varying NOT NULL,
    category character varying,
    documentation character varying
)
INHERITS (resource_component);


--
-- Name: conformance_messaging_event_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_code (
)
INHERITS (cd);


--
-- Name: conformance_messaging_event_code_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_code_vs (
)
INHERITS (cd_vs);


--
-- Name: conformance_messaging_event_protocol; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_protocol (
)
INHERITS (cd);


--
-- Name: conformance_messaging_event_protocol_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_protocol_vs (
)
INHERITS (cd_vs);


--
-- Name: conformance_messaging_event_request; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_request (
)
INHERITS (resource_reference);


--
-- Name: conformance_messaging_event_response; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_messaging_event_response (
)
INHERITS (resource_reference);


--
-- Name: conformance_profile; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_profile (
)
INHERITS (resource_reference);


--
-- Name: conformance_rest; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest (
    mode character varying NOT NULL,
    documentation character varying,
    document_mailbox character varying[]
)
INHERITS (resource_component);


--
-- Name: conformance_rest_operation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_operation (
    code character varying NOT NULL,
    documentation character varying
)
INHERITS (resource_component);


--
-- Name: conformance_rest_query; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_query (
    documentation character varying,
    name character varying NOT NULL,
    definition character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: conformance_rest_resource; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_resource (
    update_create boolean,
    read_history boolean,
    type character varying NOT NULL,
    search_include character varying[]
)
INHERITS (resource_component);


--
-- Name: conformance_rest_resource_operation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_resource_operation (
    code character varying NOT NULL,
    documentation character varying
)
INHERITS (resource_component);


--
-- Name: conformance_rest_resource_profile; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_resource_profile (
)
INHERITS (resource_reference);


--
-- Name: conformance_rest_resource_search_param; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_resource_search_param (
    type character varying NOT NULL,
    target character varying[],
    chain character varying[],
    documentation character varying,
    name character varying NOT NULL,
    definition character varying
)
INHERITS (resource_component);


--
-- Name: conformance_rest_security; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_security (
    cors boolean,
    description character varying
)
INHERITS (resource_component);


--
-- Name: conformance_rest_security_certificate; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_security_certificate (
    blob bytea,
    type character varying
)
INHERITS (resource_component);


--
-- Name: conformance_rest_security_service; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_security_service (
)
INHERITS (cc);


--
-- Name: conformance_rest_security_service_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_security_service_cd (
)
INHERITS (cc_cd);


--
-- Name: conformance_rest_security_service_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_rest_security_service_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: conformance_software; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_software (
    release_date timestamp without time zone,
    version character varying,
    name character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: conformance_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_telecom (
)
INHERITS (contact);


--
-- Name: conformance_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_telecom_period (
)
INHERITS (contact_period);


--
-- Name: conformance_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE conformance_text (
)
INHERITS (narrative);


--
-- Name: device; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device (
    expiry date,
    lot_number character varying,
    udi character varying,
    version character varying,
    model character varying,
    manufacturer character varying,
    url character varying
)
INHERITS (resource);


--
-- Name: device_contact; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_contact (
)
INHERITS (contact);


--
-- Name: device_contact_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_contact_period (
)
INHERITS (contact_period);


--
-- Name: device_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_idn (
)
INHERITS (idn);


--
-- Name: device_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: device_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_idn_period (
)
INHERITS (idn_period);


--
-- Name: device_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_loc (
)
INHERITS (resource_reference);


--
-- Name: device_observation_report; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report (
    instant timestamp without time zone NOT NULL
)
INHERITS (resource);


--
-- Name: device_observation_report_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_idn (
)
INHERITS (idn);


--
-- Name: device_observation_report_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: device_observation_report_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_idn_period (
)
INHERITS (idn_period);


--
-- Name: device_observation_report_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_source (
)
INHERITS (resource_reference);


--
-- Name: device_observation_report_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_subject (
)
INHERITS (resource_reference);


--
-- Name: device_observation_report_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_text (
)
INHERITS (narrative);


--
-- Name: device_observation_report_virtual_device; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device (
)
INHERITS (resource_component);


--
-- Name: device_observation_report_virtual_device_channel; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel (
)
INHERITS (resource_component);


--
-- Name: device_observation_report_virtual_device_channel_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel_code (
)
INHERITS (cc);


--
-- Name: device_observation_report_virtual_device_channel_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel_code_cd (
)
INHERITS (cc_cd);


--
-- Name: device_observation_report_virtual_device_channel_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: device_observation_report_virtual_device_channel_metric; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel_metric (
)
INHERITS (resource_component);


--
-- Name: device_observation_report_virtual_device_channel_metric_observa; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_channel_metric_observa (
)
INHERITS (resource_reference);


--
-- Name: device_observation_report_virtual_device_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_code (
)
INHERITS (cc);


--
-- Name: device_observation_report_virtual_device_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_code_cd (
)
INHERITS (cc_cd);


--
-- Name: device_observation_report_virtual_device_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_observation_report_virtual_device_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: device_owner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_owner (
)
INHERITS (resource_reference);


--
-- Name: device_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_patient (
)
INHERITS (resource_reference);


--
-- Name: device_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_text (
)
INHERITS (narrative);


--
-- Name: device_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_type (
)
INHERITS (cc);


--
-- Name: device_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_type_cd (
)
INHERITS (cc_cd);


--
-- Name: device_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE device_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_order; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order (
    priority character varying,
    status character varying,
    clinical_notes character varying
)
INHERITS (resource);


--
-- Name: diagnostic_order_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_encounter (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_event (
    status character varying NOT NULL,
    date_time timestamp without time zone NOT NULL
)
INHERITS (resource_component);


--
-- Name: diagnostic_order_event_actor; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_event_actor (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_event_description; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_event_description (
)
INHERITS (cc);


--
-- Name: diagnostic_order_event_description_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_event_description_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_order_event_description_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_event_description_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_order_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_idn (
)
INHERITS (idn);


--
-- Name: diagnostic_order_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: diagnostic_order_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_idn_period (
)
INHERITS (idn_period);


--
-- Name: diagnostic_order_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item (
    status character varying
)
INHERITS (resource_component);


--
-- Name: diagnostic_order_item_body_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_body_site (
)
INHERITS (cc);


--
-- Name: diagnostic_order_item_body_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_body_site_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_order_item_body_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_body_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_order_item_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_code (
)
INHERITS (cc);


--
-- Name: diagnostic_order_item_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_code_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_order_item_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_order_item_specimen; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_item_specimen (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_orderer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_orderer (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_specimen; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_specimen (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_subject (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_order_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_order_text (
)
INHERITS (narrative);


--
-- Name: diagnostic_report; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report (
    status character varying NOT NULL,
    issued timestamp without time zone NOT NULL,
    diagnostic_date_time timestamp without time zone NOT NULL,
    conclusion character varying
)
INHERITS (resource);


--
-- Name: diagnostic_report_coded_diagnosis; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_coded_diagnosis (
)
INHERITS (cc);


--
-- Name: diagnostic_report_coded_diagnosis_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_coded_diagnosis_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_report_coded_diagnosis_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_coded_diagnosis_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_report_diagnostic_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_diagnostic_period (
)
INHERITS (period);


--
-- Name: diagnostic_report_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_idn (
)
INHERITS (idn);


--
-- Name: diagnostic_report_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: diagnostic_report_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_idn_period (
)
INHERITS (idn_period);


--
-- Name: diagnostic_report_image; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_image (
    comment character varying
)
INHERITS (resource_component);


--
-- Name: diagnostic_report_image_link; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_image_link (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_imaging_study; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_imaging_study (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_name (
)
INHERITS (cc);


--
-- Name: diagnostic_report_name_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_name_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_report_name_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_name_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_report_performer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_performer (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_presented_form; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_presented_form (
)
INHERITS (attachment);


--
-- Name: diagnostic_report_request_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_request_detail (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_result; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_result (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_service_category; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_service_category (
)
INHERITS (cc);


--
-- Name: diagnostic_report_service_category_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_service_category_cd (
)
INHERITS (cc_cd);


--
-- Name: diagnostic_report_service_category_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_service_category_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: diagnostic_report_specimen; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_specimen (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_subject (
)
INHERITS (resource_reference);


--
-- Name: diagnostic_report_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE diagnostic_report_text (
)
INHERITS (narrative);


--
-- Name: document_manifest; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest (
    status character varying NOT NULL,
    created timestamp without time zone,
    description character varying,
    source character varying
)
INHERITS (resource);


--
-- Name: document_manifest_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_author (
)
INHERITS (resource_reference);


--
-- Name: document_manifest_confidentiality; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_confidentiality (
)
INHERITS (cc);


--
-- Name: document_manifest_confidentiality_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_confidentiality_cd (
)
INHERITS (cc_cd);


--
-- Name: document_manifest_confidentiality_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_confidentiality_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_manifest_content; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_content (
)
INHERITS (resource_reference);


--
-- Name: document_manifest_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_idn (
)
INHERITS (idn);


--
-- Name: document_manifest_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: document_manifest_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_idn_period (
)
INHERITS (idn_period);


--
-- Name: document_manifest_master_identifier; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_master_identifier (
)
INHERITS (idn);


--
-- Name: document_manifest_master_identifier_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_master_identifier_assigner (
)
INHERITS (idn_assigner);


--
-- Name: document_manifest_master_identifier_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_master_identifier_period (
)
INHERITS (idn_period);


--
-- Name: document_manifest_recipient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_recipient (
)
INHERITS (resource_reference);


--
-- Name: document_manifest_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_subject (
)
INHERITS (resource_reference);


--
-- Name: document_manifest_supercedes; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_supercedes (
)
INHERITS (resource_reference);


--
-- Name: document_manifest_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_text (
)
INHERITS (narrative);


--
-- Name: document_manifest_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_type (
)
INHERITS (cc);


--
-- Name: document_manifest_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_type_cd (
)
INHERITS (cc_cd);


--
-- Name: document_manifest_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_manifest_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference (
    primary_language character varying,
    status character varying NOT NULL,
    mime_type character varying NOT NULL,
    created timestamp without time zone,
    indexed timestamp without time zone NOT NULL,
    size integer,
    hash character varying,
    description character varying,
    policy_manager character varying,
    location character varying,
    format character varying[]
)
INHERITS (resource);


--
-- Name: document_reference_authenticator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_authenticator (
)
INHERITS (resource_reference);


--
-- Name: document_reference_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_author (
)
INHERITS (resource_reference);


--
-- Name: document_reference_class; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_class (
)
INHERITS (cc);


--
-- Name: document_reference_class_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_class_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_class_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_class_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_confidentiality; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_confidentiality (
)
INHERITS (cc);


--
-- Name: document_reference_confidentiality_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_confidentiality_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_confidentiality_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_confidentiality_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_context; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context (
)
INHERITS (resource_component);


--
-- Name: document_reference_context_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_event (
)
INHERITS (cc);


--
-- Name: document_reference_context_event_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_event_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_context_event_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_event_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_context_facility_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_facility_type (
)
INHERITS (cc);


--
-- Name: document_reference_context_facility_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_facility_type_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_context_facility_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_facility_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_context_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_context_period (
)
INHERITS (period);


--
-- Name: document_reference_custodian; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_custodian (
)
INHERITS (resource_reference);


--
-- Name: document_reference_doc_status; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_doc_status (
)
INHERITS (cc);


--
-- Name: document_reference_doc_status_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_doc_status_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_doc_status_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_doc_status_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_idn (
)
INHERITS (idn);


--
-- Name: document_reference_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: document_reference_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_idn_period (
)
INHERITS (idn_period);


--
-- Name: document_reference_master_identifier; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_master_identifier (
)
INHERITS (idn);


--
-- Name: document_reference_master_identifier_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_master_identifier_assigner (
)
INHERITS (idn_assigner);


--
-- Name: document_reference_master_identifier_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_master_identifier_period (
)
INHERITS (idn_period);


--
-- Name: document_reference_relates_to; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_relates_to (
    code character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: document_reference_relates_to_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_relates_to_target (
)
INHERITS (resource_reference);


--
-- Name: document_reference_service; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_service (
    address character varying
)
INHERITS (resource_component);


--
-- Name: document_reference_service_parameter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_service_parameter (
    value character varying,
    name character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: document_reference_service_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_service_type (
)
INHERITS (cc);


--
-- Name: document_reference_service_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_service_type_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_service_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_service_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: document_reference_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_subject (
)
INHERITS (resource_reference);


--
-- Name: document_reference_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_text (
)
INHERITS (narrative);


--
-- Name: document_reference_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_type (
)
INHERITS (cc);


--
-- Name: document_reference_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_type_cd (
)
INHERITS (cc_cd);


--
-- Name: document_reference_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE document_reference_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter (
    class character varying NOT NULL,
    status character varying NOT NULL
)
INHERITS (resource);


--
-- Name: encounter_hospitalization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization (
    re_admission boolean
)
INHERITS (resource_component);


--
-- Name: encounter_hospitalization_accomodation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_accomodation (
)
INHERITS (resource_component);


--
-- Name: encounter_hospitalization_accomodation_bed; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_accomodation_bed (
)
INHERITS (resource_reference);


--
-- Name: encounter_hospitalization_accomodation_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_accomodation_period (
)
INHERITS (period);


--
-- Name: encounter_hospitalization_admit_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_admit_source (
)
INHERITS (cc);


--
-- Name: encounter_hospitalization_admit_source_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_admit_source_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_hospitalization_admit_source_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_admit_source_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_hospitalization_destination; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_destination (
)
INHERITS (resource_reference);


--
-- Name: encounter_hospitalization_diet; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_diet (
)
INHERITS (cc);


--
-- Name: encounter_hospitalization_diet_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_diet_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_hospitalization_diet_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_diet_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_hospitalization_discharge_diagnosis; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_discharge_diagnosis (
)
INHERITS (resource_reference);


--
-- Name: encounter_hospitalization_discharge_disposition; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_discharge_disposition (
)
INHERITS (cc);


--
-- Name: encounter_hospitalization_discharge_disposition_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_discharge_disposition_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_hospitalization_discharge_disposition_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_discharge_disposition_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_hospitalization_origin; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_origin (
)
INHERITS (resource_reference);


--
-- Name: encounter_hospitalization_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_period (
)
INHERITS (period);


--
-- Name: encounter_hospitalization_pre_admission_identifier; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_pre_admission_identifier (
)
INHERITS (idn);


--
-- Name: encounter_hospitalization_pre_admission_identifier_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_pre_admission_identifier_assigner (
)
INHERITS (idn_assigner);


--
-- Name: encounter_hospitalization_pre_admission_identifier_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_pre_admission_identifier_period (
)
INHERITS (idn_period);


--
-- Name: encounter_hospitalization_special_arrangement; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_arrangement (
)
INHERITS (cc);


--
-- Name: encounter_hospitalization_special_arrangement_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_arrangement_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_hospitalization_special_arrangement_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_arrangement_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_hospitalization_special_courtesy; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_courtesy (
)
INHERITS (cc);


--
-- Name: encounter_hospitalization_special_courtesy_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_courtesy_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_hospitalization_special_courtesy_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_hospitalization_special_courtesy_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_idn (
)
INHERITS (idn);


--
-- Name: encounter_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: encounter_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_idn_period (
)
INHERITS (idn_period);


--
-- Name: encounter_indication; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_indication (
)
INHERITS (resource_reference);


--
-- Name: encounter_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_loc (
)
INHERITS (resource_component);


--
-- Name: encounter_loc_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_loc_loc (
)
INHERITS (resource_reference);


--
-- Name: encounter_loc_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_loc_period (
)
INHERITS (period);


--
-- Name: encounter_part_of; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_part_of (
)
INHERITS (resource_reference);


--
-- Name: encounter_participant; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_participant (
)
INHERITS (resource_component);


--
-- Name: encounter_participant_individual; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_participant_individual (
)
INHERITS (resource_reference);


--
-- Name: encounter_participant_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_participant_type (
)
INHERITS (cc);


--
-- Name: encounter_participant_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_participant_type_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_participant_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_participant_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_period (
)
INHERITS (period);


--
-- Name: encounter_priority; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_priority (
)
INHERITS (cc);


--
-- Name: encounter_priority_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_priority_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_priority_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_priority_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_reason (
)
INHERITS (cc);


--
-- Name: encounter_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: encounter_service_provider; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_service_provider (
)
INHERITS (resource_reference);


--
-- Name: encounter_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_subject (
)
INHERITS (resource_reference);


--
-- Name: encounter_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_text (
)
INHERITS (narrative);


--
-- Name: encounter_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_type (
)
INHERITS (cc);


--
-- Name: encounter_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_type_cd (
)
INHERITS (cc_cd);


--
-- Name: encounter_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE encounter_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: family_history; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history (
    note character varying
)
INHERITS (resource);


--
-- Name: family_history_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_idn (
)
INHERITS (idn);


--
-- Name: family_history_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: family_history_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_idn_period (
)
INHERITS (idn_period);


--
-- Name: family_history_relation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation (
    deceased_boolean boolean,
    born_date date,
    deceased_date date,
    note character varying,
    deceased_string character varying,
    born_string character varying,
    name character varying
)
INHERITS (resource_component);


--
-- Name: family_history_relation_born_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_born_period (
)
INHERITS (period);


--
-- Name: family_history_relation_condition; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition (
    note character varying,
    onset_string character varying
)
INHERITS (resource_component);


--
-- Name: range; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE range (
)
INHERITS (resource_component);


--
-- Name: family_history_relation_condition_onset_range; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_onset_range (
)
INHERITS (range);


--
-- Name: range_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE range_high (
)
INHERITS (quantity);


--
-- Name: family_history_relation_condition_onset_range_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_onset_range_high (
)
INHERITS (range_high);


--
-- Name: range_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE range_low (
)
INHERITS (quantity);


--
-- Name: family_history_relation_condition_onset_range_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_onset_range_low (
)
INHERITS (range_low);


--
-- Name: family_history_relation_condition_outcome; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_outcome (
)
INHERITS (cc);


--
-- Name: family_history_relation_condition_outcome_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_outcome_cd (
)
INHERITS (cc_cd);


--
-- Name: family_history_relation_condition_outcome_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_outcome_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: family_history_relation_condition_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_type (
)
INHERITS (cc);


--
-- Name: family_history_relation_condition_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_type_cd (
)
INHERITS (cc_cd);


--
-- Name: family_history_relation_condition_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_condition_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: family_history_relation_deceased_range; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_deceased_range (
)
INHERITS (range);


--
-- Name: family_history_relation_deceased_range_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_deceased_range_high (
)
INHERITS (range_high);


--
-- Name: family_history_relation_deceased_range_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_deceased_range_low (
)
INHERITS (range_low);


--
-- Name: family_history_relation_relationship; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_relationship (
)
INHERITS (cc);


--
-- Name: family_history_relation_relationship_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_relationship_cd (
)
INHERITS (cc_cd);


--
-- Name: family_history_relation_relationship_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_relation_relationship_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: family_history_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_subject (
)
INHERITS (resource_reference);


--
-- Name: family_history_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE family_history_text (
)
INHERITS (narrative);


--
-- Name: group; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE "group" (
    actual boolean NOT NULL,
    type character varying NOT NULL,
    quantity integer,
    name character varying
)
INHERITS (resource);


--
-- Name: group_characteristic; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic (
    exclude boolean NOT NULL,
    value_boolean boolean NOT NULL
)
INHERITS (resource_component);


--
-- Name: group_characteristic_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_code (
)
INHERITS (cc);


--
-- Name: group_characteristic_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_code_cd (
)
INHERITS (cc_cd);


--
-- Name: group_characteristic_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: group_characteristic_value_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_codeable_concept (
)
INHERITS (cc);


--
-- Name: group_characteristic_value_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: group_characteristic_value_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: group_characteristic_value_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_quantity (
)
INHERITS (quantity);


--
-- Name: group_characteristic_value_range; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_range (
)
INHERITS (range);


--
-- Name: group_characteristic_value_range_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_range_high (
)
INHERITS (range_high);


--
-- Name: group_characteristic_value_range_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_characteristic_value_range_low (
)
INHERITS (range_low);


--
-- Name: group_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_code (
)
INHERITS (cc);


--
-- Name: group_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_code_cd (
)
INHERITS (cc_cd);


--
-- Name: group_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: group_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_idn (
)
INHERITS (idn);


--
-- Name: group_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: group_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_idn_period (
)
INHERITS (idn_period);


--
-- Name: group_member; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_member (
)
INHERITS (resource_reference);


--
-- Name: group_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE group_text (
)
INHERITS (narrative);


--
-- Name: human_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE human_name (
    use "NameUse",
    text character varying,
    family character varying[],
    given character varying[],
    prefix character varying[],
    suffix character varying[]
)
INHERITS (resource_component);


--
-- Name: human_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE human_name_period (
)
INHERITS (period);


--
-- Name: imaging_study; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study (
    modality character varying[],
    availability character varying,
    date_time timestamp without time zone,
    number_of_series integer NOT NULL,
    number_of_instances integer NOT NULL,
    uid character varying NOT NULL,
    description character varying,
    clinical_information character varying,
    url character varying
)
INHERITS (resource);


--
-- Name: imaging_study_accession_no; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_accession_no (
)
INHERITS (idn);


--
-- Name: imaging_study_accession_no_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_accession_no_assigner (
)
INHERITS (idn_assigner);


--
-- Name: imaging_study_accession_no_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_accession_no_period (
)
INHERITS (idn_period);


--
-- Name: imaging_study_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_idn (
)
INHERITS (idn);


--
-- Name: imaging_study_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: imaging_study_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_idn_period (
)
INHERITS (idn_period);


--
-- Name: imaging_study_interpreter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_interpreter (
)
INHERITS (resource_reference);


--
-- Name: imaging_study_order; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_order (
)
INHERITS (resource_reference);


--
-- Name: imaging_study_procedure; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_procedure (
)
INHERITS (cd);


--
-- Name: imaging_study_procedure_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_procedure_vs (
)
INHERITS (cd_vs);


--
-- Name: imaging_study_referrer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_referrer (
)
INHERITS (resource_reference);


--
-- Name: imaging_study_series; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_series (
    availability character varying,
    modality character varying NOT NULL,
    date_time timestamp without time zone,
    number integer,
    number_of_instances integer NOT NULL,
    uid character varying NOT NULL,
    description character varying,
    url character varying
)
INHERITS (resource_component);


--
-- Name: imaging_study_series_body_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_series_body_site (
)
INHERITS (cd);


--
-- Name: imaging_study_series_body_site_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_series_body_site_vs (
)
INHERITS (cd_vs);


--
-- Name: imaging_study_series_instance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_series_instance (
    number integer,
    sopclass character varying NOT NULL,
    uid character varying NOT NULL,
    title character varying,
    type character varying,
    url character varying
)
INHERITS (resource_component);


--
-- Name: imaging_study_series_instance_attachment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_series_instance_attachment (
)
INHERITS (resource_reference);


--
-- Name: imaging_study_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_subject (
)
INHERITS (resource_reference);


--
-- Name: imaging_study_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imaging_study_text (
)
INHERITS (narrative);


--
-- Name: imm; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm (
    reported boolean NOT NULL,
    refused_indicator boolean NOT NULL,
    expiration_date date,
    date timestamp without time zone NOT NULL,
    lot_number character varying
)
INHERITS (resource);


--
-- Name: imm_dose_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_dose_quantity (
)
INHERITS (quantity);


--
-- Name: imm_explanation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation (
)
INHERITS (resource_component);


--
-- Name: imm_explanation_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_reason (
)
INHERITS (cc);


--
-- Name: imm_explanation_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_explanation_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_explanation_refusal_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_refusal_reason (
)
INHERITS (cc);


--
-- Name: imm_explanation_refusal_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_refusal_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_explanation_refusal_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_explanation_refusal_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_idn (
)
INHERITS (idn);


--
-- Name: imm_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: imm_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_idn_period (
)
INHERITS (idn_period);


--
-- Name: imm_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_loc (
)
INHERITS (resource_reference);


--
-- Name: imm_manufacturer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_manufacturer (
)
INHERITS (resource_reference);


--
-- Name: imm_performer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_performer (
)
INHERITS (resource_reference);


--
-- Name: imm_reaction; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_reaction (
    reported boolean,
    date timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: imm_reaction_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_reaction_detail (
)
INHERITS (resource_reference);


--
-- Name: imm_rec; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec (
)
INHERITS (resource);


--
-- Name: imm_rec_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_idn (
)
INHERITS (idn);


--
-- Name: imm_rec_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: imm_rec_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_idn_period (
)
INHERITS (idn_period);


--
-- Name: imm_rec_recommendation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation (
    date timestamp without time zone NOT NULL,
    dose_number integer
)
INHERITS (resource_component);


--
-- Name: imm_rec_recommendation_date_criterion; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_date_criterion (
    value timestamp without time zone NOT NULL
)
INHERITS (resource_component);


--
-- Name: imm_rec_recommendation_date_criterion_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_date_criterion_code (
)
INHERITS (cc);


--
-- Name: imm_rec_recommendation_date_criterion_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_date_criterion_code_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_rec_recommendation_date_criterion_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_date_criterion_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_rec_recommendation_forecast_status; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_forecast_status (
)
INHERITS (cc);


--
-- Name: imm_rec_recommendation_forecast_status_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_forecast_status_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_rec_recommendation_forecast_status_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_forecast_status_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_rec_recommendation_protocol; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_protocol (
    dose_sequence integer,
    series character varying,
    description character varying
)
INHERITS (resource_component);


--
-- Name: imm_rec_recommendation_protocol_authority; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_protocol_authority (
)
INHERITS (resource_reference);


--
-- Name: imm_rec_recommendation_supporting_immunization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_supporting_immunization (
)
INHERITS (resource_reference);


--
-- Name: imm_rec_recommendation_supporting_patient_information; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_supporting_patient_information (
)
INHERITS (resource_reference);


--
-- Name: imm_rec_recommendation_vaccine_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_vaccine_type (
)
INHERITS (cc);


--
-- Name: imm_rec_recommendation_vaccine_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_vaccine_type_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_rec_recommendation_vaccine_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_recommendation_vaccine_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_rec_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_subject (
)
INHERITS (resource_reference);


--
-- Name: imm_rec_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_rec_text (
)
INHERITS (narrative);


--
-- Name: imm_requester; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_requester (
)
INHERITS (resource_reference);


--
-- Name: imm_route; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_route (
)
INHERITS (cc);


--
-- Name: imm_route_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_route_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_route_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_route_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_site (
)
INHERITS (cc);


--
-- Name: imm_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_site_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_subject (
)
INHERITS (resource_reference);


--
-- Name: imm_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_text (
)
INHERITS (narrative);


--
-- Name: imm_vaccination_protocol; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol (
    dose_sequence integer NOT NULL,
    series_doses integer,
    series character varying,
    description character varying
)
INHERITS (resource_component);


--
-- Name: imm_vaccination_protocol_authority; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_authority (
)
INHERITS (resource_reference);


--
-- Name: imm_vaccination_protocol_dose_status; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status (
)
INHERITS (cc);


--
-- Name: imm_vaccination_protocol_dose_status_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_vaccination_protocol_dose_status_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_vaccination_protocol_dose_status_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status_reason (
)
INHERITS (cc);


--
-- Name: imm_vaccination_protocol_dose_status_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_vaccination_protocol_dose_status_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_status_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_vaccination_protocol_dose_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_target (
)
INHERITS (cc);


--
-- Name: imm_vaccination_protocol_dose_target_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_target_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_vaccination_protocol_dose_target_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccination_protocol_dose_target_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: imm_vaccine_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccine_type (
)
INHERITS (cc);


--
-- Name: imm_vaccine_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccine_type_cd (
)
INHERITS (cc_cd);


--
-- Name: imm_vaccine_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE imm_vaccine_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: list; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list (
    ordered boolean,
    mode character varying NOT NULL,
    date timestamp without time zone
)
INHERITS (resource);


--
-- Name: list_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_code (
)
INHERITS (cc);


--
-- Name: list_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_code_cd (
)
INHERITS (cc_cd);


--
-- Name: list_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: list_empty_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_empty_reason (
)
INHERITS (cc);


--
-- Name: list_empty_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_empty_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: list_empty_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_empty_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: list_entry; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_entry (
    deleted boolean,
    date timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: list_entry_flag; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_entry_flag (
)
INHERITS (cc);


--
-- Name: list_entry_flag_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_entry_flag_cd (
)
INHERITS (cc_cd);


--
-- Name: list_entry_flag_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_entry_flag_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: list_entry_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_entry_item (
)
INHERITS (resource_reference);


--
-- Name: list_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_idn (
)
INHERITS (idn);


--
-- Name: list_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: list_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_idn_period (
)
INHERITS (idn_period);


--
-- Name: list_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_source (
)
INHERITS (resource_reference);


--
-- Name: list_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_subject (
)
INHERITS (resource_reference);


--
-- Name: list_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE list_text (
)
INHERITS (narrative);


--
-- Name: loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc (
    status character varying,
    mode character varying,
    name character varying,
    description character varying
)
INHERITS (resource);


--
-- Name: loc_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_address (
)
INHERITS (address);


--
-- Name: loc_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_address_period (
)
INHERITS (address_period);


--
-- Name: loc_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_idn (
)
INHERITS (idn);


--
-- Name: loc_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: loc_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_idn_period (
)
INHERITS (idn_period);


--
-- Name: loc_managing_organization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_managing_organization (
)
INHERITS (resource_reference);


--
-- Name: loc_part_of; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_part_of (
)
INHERITS (resource_reference);


--
-- Name: loc_physical_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_physical_type (
)
INHERITS (cc);


--
-- Name: loc_physical_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_physical_type_cd (
)
INHERITS (cc_cd);


--
-- Name: loc_physical_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_physical_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: loc_position; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_position (
    altitude numeric,
    latitude numeric NOT NULL,
    longitude numeric NOT NULL
)
INHERITS (resource_component);


--
-- Name: loc_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_telecom (
)
INHERITS (contact);


--
-- Name: loc_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_telecom_period (
)
INHERITS (contact_period);


--
-- Name: loc_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_text (
)
INHERITS (narrative);


--
-- Name: loc_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_type (
)
INHERITS (cc);


--
-- Name: loc_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_type_cd (
)
INHERITS (cc_cd);


--
-- Name: loc_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE loc_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med (
    is_brand boolean,
    kind character varying,
    name character varying
)
INHERITS (resource);


--
-- Name: med_adm; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm (
    was_not_given boolean,
    status character varying NOT NULL
)
INHERITS (resource);


--
-- Name: med_adm_device; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_device (
)
INHERITS (resource_reference);


--
-- Name: med_adm_dosage; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage (
    as_needed_boolean boolean,
    timing_date_time timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: med_adm_dosage_as_needed_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_as_needed_codeable_concept (
)
INHERITS (cc);


--
-- Name: med_adm_dosage_as_needed_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_as_needed_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: med_adm_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_as_needed_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: ratio; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE ratio (
)
INHERITS (resource_component);


--
-- Name: med_adm_dosage_max_dose_per_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_max_dose_per_period (
)
INHERITS (ratio);


--
-- Name: ratio_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE ratio_denominator (
)
INHERITS (quantity);


--
-- Name: med_adm_dosage_max_dose_per_period_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_max_dose_per_period_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: ratio_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE ratio_numerator (
)
INHERITS (quantity);


--
-- Name: med_adm_dosage_max_dose_per_period_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_max_dose_per_period_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_adm_dosage_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_method (
)
INHERITS (cc);


--
-- Name: med_adm_dosage_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_method_cd (
)
INHERITS (cc_cd);


--
-- Name: med_adm_dosage_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_adm_dosage_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_quantity (
)
INHERITS (quantity);


--
-- Name: med_adm_dosage_rate; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_rate (
)
INHERITS (ratio);


--
-- Name: med_adm_dosage_rate_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_rate_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_adm_dosage_rate_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_rate_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_adm_dosage_route; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_route (
)
INHERITS (cc);


--
-- Name: med_adm_dosage_route_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_route_cd (
)
INHERITS (cc_cd);


--
-- Name: med_adm_dosage_route_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_route_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_adm_dosage_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_site (
)
INHERITS (cc);


--
-- Name: med_adm_dosage_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_site_cd (
)
INHERITS (cc_cd);


--
-- Name: med_adm_dosage_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_adm_dosage_timing_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_dosage_timing_period (
)
INHERITS (period);


--
-- Name: med_adm_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_encounter (
)
INHERITS (resource_reference);


--
-- Name: med_adm_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_idn (
)
INHERITS (idn);


--
-- Name: med_adm_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: med_adm_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_idn_period (
)
INHERITS (idn_period);


--
-- Name: med_adm_med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_med (
)
INHERITS (resource_reference);


--
-- Name: med_adm_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_patient (
)
INHERITS (resource_reference);


--
-- Name: med_adm_practitioner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_practitioner (
)
INHERITS (resource_reference);


--
-- Name: med_adm_prs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_prs (
)
INHERITS (resource_reference);


--
-- Name: med_adm_reason_not_given; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_reason_not_given (
)
INHERITS (cc);


--
-- Name: med_adm_reason_not_given_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_reason_not_given_cd (
)
INHERITS (cc_cd);


--
-- Name: med_adm_reason_not_given_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_reason_not_given_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_adm_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_text (
)
INHERITS (narrative);


--
-- Name: med_adm_when_given; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_adm_when_given (
)
INHERITS (period);


--
-- Name: med_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_code (
)
INHERITS (cc);


--
-- Name: med_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_code_cd (
)
INHERITS (cc_cd);


--
-- Name: med_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp (
    status character varying
)
INHERITS (resource);


--
-- Name: med_disp_authorizing_prescription; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_authorizing_prescription (
)
INHERITS (resource_reference);


--
-- Name: med_disp_dispense; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense (
    status character varying,
    when_prepared timestamp without time zone,
    when_handed_over timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: med_disp_dispense_destination; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_destination (
)
INHERITS (resource_reference);


--
-- Name: med_disp_dispense_dosage; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage (
    as_needed_boolean boolean,
    timing_date_time timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: med_disp_dispense_dosage_additional_instructions; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_additional_instructions (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_dosage_additional_instructions_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_additional_instructions_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_dosage_additional_instructions_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_additional_instructions_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispense_dosage_as_needed_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_as_needed_codeable_concept (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_dosage_as_needed_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_as_needed_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispense_dosage_max_dose_per_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_max_dose_per_period (
)
INHERITS (ratio);


--
-- Name: med_disp_dispense_dosage_max_dose_per_period_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_max_dose_per_period_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_disp_dispense_dosage_max_dose_per_period_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_max_dose_per_period_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_disp_dispense_dosage_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_method (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_dosage_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_method_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_dosage_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispense_dosage_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_quantity (
)
INHERITS (quantity);


--
-- Name: med_disp_dispense_dosage_rate; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_rate (
)
INHERITS (ratio);


--
-- Name: med_disp_dispense_dosage_rate_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_rate_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_disp_dispense_dosage_rate_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_rate_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_disp_dispense_dosage_route; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_route (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_dosage_route_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_route_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_dosage_route_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_route_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispense_dosage_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_site (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_dosage_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_site_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_dosage_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispense_dosage_timing_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_timing_period (
)
INHERITS (period);


--
-- Name: med_disp_dispense_dosage_timing_schedule; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_timing_schedule (
)
INHERITS (schedule);


--
-- Name: med_disp_dispense_dosage_timing_schedule_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_timing_schedule_event (
)
INHERITS (schedule_event);


--
-- Name: med_disp_dispense_dosage_timing_schedule_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_dosage_timing_schedule_repeat (
)
INHERITS (schedule_repeat);


--
-- Name: med_disp_dispense_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_idn (
)
INHERITS (idn);


--
-- Name: med_disp_dispense_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: med_disp_dispense_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_idn_period (
)
INHERITS (idn_period);


--
-- Name: med_disp_dispense_med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_med (
)
INHERITS (resource_reference);


--
-- Name: med_disp_dispense_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_quantity (
)
INHERITS (quantity);


--
-- Name: med_disp_dispense_receiver; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_receiver (
)
INHERITS (resource_reference);


--
-- Name: med_disp_dispense_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_type (
)
INHERITS (cc);


--
-- Name: med_disp_dispense_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_type_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_dispense_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispense_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_dispenser; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_dispenser (
)
INHERITS (resource_reference);


--
-- Name: med_disp_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_idn (
)
INHERITS (idn);


--
-- Name: med_disp_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: med_disp_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_idn_period (
)
INHERITS (idn_period);


--
-- Name: med_disp_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_patient (
)
INHERITS (resource_reference);


--
-- Name: med_disp_substitution; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution (
)
INHERITS (resource_component);


--
-- Name: med_disp_substitution_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_reason (
)
INHERITS (cc);


--
-- Name: med_disp_substitution_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_substitution_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_substitution_responsible_party; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_responsible_party (
)
INHERITS (resource_reference);


--
-- Name: med_disp_substitution_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_type (
)
INHERITS (cc);


--
-- Name: med_disp_substitution_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_type_cd (
)
INHERITS (cc_cd);


--
-- Name: med_disp_substitution_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_substitution_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_disp_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_disp_text (
)
INHERITS (narrative);


--
-- Name: med_manufacturer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_manufacturer (
)
INHERITS (resource_reference);


--
-- Name: med_package; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package (
)
INHERITS (resource_component);


--
-- Name: med_package_container; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_container (
)
INHERITS (cc);


--
-- Name: med_package_container_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_container_cd (
)
INHERITS (cc_cd);


--
-- Name: med_package_container_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_container_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_package_content; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_content (
)
INHERITS (resource_component);


--
-- Name: med_package_content_amount; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_content_amount (
)
INHERITS (quantity);


--
-- Name: med_package_content_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_package_content_item (
)
INHERITS (resource_reference);


--
-- Name: med_product; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product (
)
INHERITS (resource_component);


--
-- Name: med_product_form; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_form (
)
INHERITS (cc);


--
-- Name: med_product_form_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_form_cd (
)
INHERITS (cc_cd);


--
-- Name: med_product_form_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_form_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_product_ingredient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_ingredient (
)
INHERITS (resource_component);


--
-- Name: med_product_ingredient_amount; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_ingredient_amount (
)
INHERITS (ratio);


--
-- Name: med_product_ingredient_amount_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_ingredient_amount_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_product_ingredient_amount_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_ingredient_amount_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_product_ingredient_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_product_ingredient_item (
)
INHERITS (resource_reference);


--
-- Name: med_prs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs (
    status character varying,
    date_written timestamp without time zone
)
INHERITS (resource);


--
-- Name: med_prs_dispense; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dispense (
    number_of_repeats_allowed integer
)
INHERITS (resource_component);


--
-- Name: med_prs_dispense_med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dispense_med (
)
INHERITS (resource_reference);


--
-- Name: med_prs_dispense_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dispense_quantity (
)
INHERITS (quantity);


--
-- Name: med_prs_dispense_validity_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dispense_validity_period (
)
INHERITS (period);


--
-- Name: med_prs_dosage_instruction; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction (
    as_needed_boolean boolean,
    timing_date_time timestamp without time zone,
    text character varying
)
INHERITS (resource_component);


--
-- Name: med_prs_dosage_instruction_additional_instructions; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_additional_instructions (
)
INHERITS (cc);


--
-- Name: med_prs_dosage_instruction_additional_instructions_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_additional_instructions_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_dosage_instruction_additional_instructions_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_additional_instructions_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_dosage_instruction_as_needed_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_as_needed_codeable_concept (
)
INHERITS (cc);


--
-- Name: med_prs_dosage_instruction_as_needed_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_as_needed_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_dosage_instruction_dose_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_dose_quantity (
)
INHERITS (quantity);


--
-- Name: med_prs_dosage_instruction_max_dose_per_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_max_dose_per_period (
)
INHERITS (ratio);


--
-- Name: med_prs_dosage_instruction_max_dose_per_period_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_max_dose_per_period_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_prs_dosage_instruction_max_dose_per_period_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_max_dose_per_period_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_prs_dosage_instruction_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_method (
)
INHERITS (cc);


--
-- Name: med_prs_dosage_instruction_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_method_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_dosage_instruction_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_dosage_instruction_rate; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_rate (
)
INHERITS (ratio);


--
-- Name: med_prs_dosage_instruction_rate_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_rate_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_prs_dosage_instruction_rate_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_rate_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_prs_dosage_instruction_route; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_route (
)
INHERITS (cc);


--
-- Name: med_prs_dosage_instruction_route_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_route_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_dosage_instruction_route_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_route_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_dosage_instruction_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_site (
)
INHERITS (cc);


--
-- Name: med_prs_dosage_instruction_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_site_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_dosage_instruction_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_dosage_instruction_timing_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_timing_period (
)
INHERITS (period);


--
-- Name: med_prs_dosage_instruction_timing_schedule; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_timing_schedule (
)
INHERITS (schedule);


--
-- Name: med_prs_dosage_instruction_timing_schedule_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_timing_schedule_event (
)
INHERITS (schedule_event);


--
-- Name: med_prs_dosage_instruction_timing_schedule_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_dosage_instruction_timing_schedule_repeat (
)
INHERITS (schedule_repeat);


--
-- Name: med_prs_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_encounter (
)
INHERITS (resource_reference);


--
-- Name: med_prs_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_idn (
)
INHERITS (idn);


--
-- Name: med_prs_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: med_prs_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_idn_period (
)
INHERITS (idn_period);


--
-- Name: med_prs_med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_med (
)
INHERITS (resource_reference);


--
-- Name: med_prs_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_patient (
)
INHERITS (resource_reference);


--
-- Name: med_prs_prescriber; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_prescriber (
)
INHERITS (resource_reference);


--
-- Name: med_prs_reason_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_reason_codeable_concept (
)
INHERITS (cc);


--
-- Name: med_prs_reason_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_reason_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_reason_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_reason_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_reason_resource_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_reason_resource_reference (
)
INHERITS (resource_reference);


--
-- Name: med_prs_substitution; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution (
)
INHERITS (resource_component);


--
-- Name: med_prs_substitution_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_reason (
)
INHERITS (cc);


--
-- Name: med_prs_substitution_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_substitution_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_substitution_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_type (
)
INHERITS (cc);


--
-- Name: med_prs_substitution_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_type_cd (
)
INHERITS (cc_cd);


--
-- Name: med_prs_substitution_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_substitution_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_prs_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_prs_text (
)
INHERITS (narrative);


--
-- Name: med_st; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st (
    was_not_given boolean
)
INHERITS (resource);


--
-- Name: med_st_device; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_device (
)
INHERITS (resource_reference);


--
-- Name: med_st_dosage; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage (
    as_needed_boolean boolean
)
INHERITS (resource_component);


--
-- Name: med_st_dosage_as_needed_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_as_needed_codeable_concept (
)
INHERITS (cc);


--
-- Name: med_st_dosage_as_needed_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_as_needed_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: med_st_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_as_needed_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_st_dosage_max_dose_per_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_max_dose_per_period (
)
INHERITS (ratio);


--
-- Name: med_st_dosage_max_dose_per_period_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_max_dose_per_period_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_st_dosage_max_dose_per_period_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_max_dose_per_period_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_st_dosage_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_method (
)
INHERITS (cc);


--
-- Name: med_st_dosage_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_method_cd (
)
INHERITS (cc_cd);


--
-- Name: med_st_dosage_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_st_dosage_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_quantity (
)
INHERITS (quantity);


--
-- Name: med_st_dosage_rate; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_rate (
)
INHERITS (ratio);


--
-- Name: med_st_dosage_rate_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_rate_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: med_st_dosage_rate_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_rate_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: med_st_dosage_route; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_route (
)
INHERITS (cc);


--
-- Name: med_st_dosage_route_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_route_cd (
)
INHERITS (cc_cd);


--
-- Name: med_st_dosage_route_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_route_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_st_dosage_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_site (
)
INHERITS (cc);


--
-- Name: med_st_dosage_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_site_cd (
)
INHERITS (cc_cd);


--
-- Name: med_st_dosage_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_st_dosage_timing; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_timing (
)
INHERITS (schedule);


--
-- Name: med_st_dosage_timing_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_timing_event (
)
INHERITS (schedule_event);


--
-- Name: med_st_dosage_timing_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_dosage_timing_repeat (
)
INHERITS (schedule_repeat);


--
-- Name: med_st_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_idn (
)
INHERITS (idn);


--
-- Name: med_st_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: med_st_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_idn_period (
)
INHERITS (idn_period);


--
-- Name: med_st_med; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_med (
)
INHERITS (resource_reference);


--
-- Name: med_st_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_patient (
)
INHERITS (resource_reference);


--
-- Name: med_st_reason_not_given; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_reason_not_given (
)
INHERITS (cc);


--
-- Name: med_st_reason_not_given_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_reason_not_given_cd (
)
INHERITS (cc_cd);


--
-- Name: med_st_reason_not_given_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_reason_not_given_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: med_st_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_text (
)
INHERITS (narrative);


--
-- Name: med_st_when_given; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_st_when_given (
)
INHERITS (period);


--
-- Name: med_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE med_text (
)
INHERITS (narrative);


--
-- Name: media; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media (
    type character varying NOT NULL,
    date_time timestamp without time zone,
    width integer,
    frames integer,
    length integer,
    height integer,
    device_name character varying
)
INHERITS (resource);


--
-- Name: media_content; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_content (
)
INHERITS (attachment);


--
-- Name: media_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_idn (
)
INHERITS (idn);


--
-- Name: media_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: media_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_idn_period (
)
INHERITS (idn_period);


--
-- Name: media_operator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_operator (
)
INHERITS (resource_reference);


--
-- Name: media_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_subject (
)
INHERITS (resource_reference);


--
-- Name: media_subtype; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_subtype (
)
INHERITS (cc);


--
-- Name: media_subtype_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_subtype_cd (
)
INHERITS (cc_cd);


--
-- Name: media_subtype_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_subtype_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: media_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_text (
)
INHERITS (narrative);


--
-- Name: media_view; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_view (
)
INHERITS (cc);


--
-- Name: media_view_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_view_cd (
)
INHERITS (cc_cd);


--
-- Name: media_view_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE media_view_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: message_header; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header (
    identifier character varying NOT NULL,
    "timestamp" timestamp without time zone NOT NULL
)
INHERITS (resource);


--
-- Name: message_header_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_author (
)
INHERITS (resource_reference);


--
-- Name: message_header_data; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_data (
)
INHERITS (resource_reference);


--
-- Name: message_header_destination; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_destination (
    name character varying,
    endpoint character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: message_header_destination_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_destination_target (
)
INHERITS (resource_reference);


--
-- Name: message_header_enterer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_enterer (
)
INHERITS (resource_reference);


--
-- Name: message_header_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_event (
)
INHERITS (cd);


--
-- Name: message_header_event_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_event_vs (
)
INHERITS (cd_vs);


--
-- Name: message_header_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_reason (
)
INHERITS (cc);


--
-- Name: message_header_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: message_header_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: message_header_receiver; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_receiver (
)
INHERITS (resource_reference);


--
-- Name: message_header_response; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_response (
    code character varying NOT NULL,
    identifier character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: message_header_response_details; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_response_details (
)
INHERITS (resource_reference);


--
-- Name: message_header_responsible; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_responsible (
)
INHERITS (resource_reference);


--
-- Name: message_header_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_source (
    name character varying,
    software character varying NOT NULL,
    version character varying,
    endpoint character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: message_header_source_contact; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_source_contact (
)
INHERITS (contact);


--
-- Name: message_header_source_contact_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_source_contact_period (
)
INHERITS (contact_period);


--
-- Name: message_header_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE message_header_text (
)
INHERITS (narrative);


--
-- Name: observation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation (
    status character varying NOT NULL,
    reliability character varying NOT NULL,
    applies_date_time timestamp without time zone,
    issued timestamp without time zone,
    value_string character varying,
    comments character varying
)
INHERITS (resource);


--
-- Name: observation_applies_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_applies_period (
)
INHERITS (period);


--
-- Name: observation_body_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_body_site (
)
INHERITS (cc);


--
-- Name: observation_body_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_body_site_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_body_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_body_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_idn (
)
INHERITS (idn);


--
-- Name: observation_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: observation_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_idn_period (
)
INHERITS (idn_period);


--
-- Name: observation_interpretation; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_interpretation (
)
INHERITS (cc);


--
-- Name: observation_interpretation_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_interpretation_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_interpretation_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_interpretation_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_method (
)
INHERITS (cc);


--
-- Name: observation_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_method_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_name (
)
INHERITS (cc);


--
-- Name: observation_name_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_name_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_name_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_name_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_performer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_performer (
)
INHERITS (resource_reference);


--
-- Name: observation_reference_range; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range (
)
INHERITS (resource_component);


--
-- Name: observation_reference_range_age; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_age (
)
INHERITS (range);


--
-- Name: observation_reference_range_age_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_age_high (
)
INHERITS (range_high);


--
-- Name: observation_reference_range_age_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_age_low (
)
INHERITS (range_low);


--
-- Name: observation_reference_range_high; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_high (
)
INHERITS (quantity);


--
-- Name: observation_reference_range_low; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_low (
)
INHERITS (quantity);


--
-- Name: observation_reference_range_meaning; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_meaning (
)
INHERITS (cc);


--
-- Name: observation_reference_range_meaning_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_meaning_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_reference_range_meaning_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_reference_range_meaning_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_related; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_related (
    type character varying
)
INHERITS (resource_component);


--
-- Name: observation_related_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_related_target (
)
INHERITS (resource_reference);


--
-- Name: observation_specimen; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_specimen (
)
INHERITS (resource_reference);


--
-- Name: observation_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_subject (
)
INHERITS (resource_reference);


--
-- Name: observation_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_text (
)
INHERITS (narrative);


--
-- Name: observation_value_attachment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_attachment (
)
INHERITS (attachment);


--
-- Name: observation_value_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_codeable_concept (
)
INHERITS (cc);


--
-- Name: observation_value_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: observation_value_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: observation_value_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_period (
)
INHERITS (period);


--
-- Name: observation_value_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_quantity (
)
INHERITS (quantity);


--
-- Name: observation_value_ratio; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_ratio (
)
INHERITS (ratio);


--
-- Name: observation_value_ratio_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_ratio_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: observation_value_ratio_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_ratio_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: sampled_data; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE sampled_data (
    period numeric NOT NULL,
    factor numeric,
    lower_limit numeric,
    upper_limit numeric,
    dimensions integer NOT NULL,
    data text NOT NULL
)
INHERITS (resource_component);


--
-- Name: observation_value_sampled_data; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_sampled_data (
)
INHERITS (sampled_data);


--
-- Name: sampled_data_origin; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE sampled_data_origin (
)
INHERITS (quantity);


--
-- Name: observation_value_sampled_data_origin; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE observation_value_sampled_data_origin (
)
INHERITS (sampled_data_origin);


--
-- Name: operation_outcome; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE operation_outcome (
)
INHERITS (resource);


--
-- Name: operation_outcome_issue; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE operation_outcome_issue (
    severity character varying NOT NULL,
    details character varying,
    location character varying[]
)
INHERITS (resource_component);


--
-- Name: operation_outcome_issue_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE operation_outcome_issue_type (
)
INHERITS (cd);


--
-- Name: operation_outcome_issue_type_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE operation_outcome_issue_type_vs (
)
INHERITS (cd_vs);


--
-- Name: operation_outcome_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE operation_outcome_text (
)
INHERITS (narrative);


--
-- Name: order; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE "order" (
    date timestamp without time zone
)
INHERITS (resource);


--
-- Name: order_authority; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_authority (
)
INHERITS (resource_reference);


--
-- Name: order_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_detail (
)
INHERITS (resource_reference);


--
-- Name: order_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_idn (
)
INHERITS (idn);


--
-- Name: order_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: order_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_idn_period (
)
INHERITS (idn_period);


--
-- Name: order_reason_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_reason_codeable_concept (
)
INHERITS (cc);


--
-- Name: order_reason_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_reason_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: order_reason_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_reason_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: order_reason_resource_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_reason_resource_reference (
)
INHERITS (resource_reference);


--
-- Name: order_response; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response (
    code character varying NOT NULL,
    date timestamp without time zone,
    description character varying
)
INHERITS (resource);


--
-- Name: order_response_authority_codeable_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_authority_codeable_concept (
)
INHERITS (cc);


--
-- Name: order_response_authority_codeable_concept_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_authority_codeable_concept_cd (
)
INHERITS (cc_cd);


--
-- Name: order_response_authority_codeable_concept_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_authority_codeable_concept_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: order_response_authority_resource_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_authority_resource_reference (
)
INHERITS (resource_reference);


--
-- Name: order_response_fulfillment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_fulfillment (
)
INHERITS (resource_reference);


--
-- Name: order_response_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_idn (
)
INHERITS (idn);


--
-- Name: order_response_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: order_response_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_idn_period (
)
INHERITS (idn_period);


--
-- Name: order_response_request; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_request (
)
INHERITS (resource_reference);


--
-- Name: order_response_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_text (
)
INHERITS (narrative);


--
-- Name: order_response_who; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_response_who (
)
INHERITS (resource_reference);


--
-- Name: order_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_source (
)
INHERITS (resource_reference);


--
-- Name: order_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_subject (
)
INHERITS (resource_reference);


--
-- Name: order_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_target (
)
INHERITS (resource_reference);


--
-- Name: order_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_text (
)
INHERITS (narrative);


--
-- Name: order_when; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when (
)
INHERITS (resource_component);


--
-- Name: order_when_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_code (
)
INHERITS (cc);


--
-- Name: order_when_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_code_cd (
)
INHERITS (cc_cd);


--
-- Name: order_when_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: order_when_schedule; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_schedule (
)
INHERITS (schedule);


--
-- Name: order_when_schedule_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_schedule_event (
)
INHERITS (schedule_event);


--
-- Name: order_when_schedule_repeat; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE order_when_schedule_repeat (
)
INHERITS (schedule_repeat);


--
-- Name: organization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization (
    active boolean,
    name character varying
)
INHERITS (resource);


--
-- Name: organization_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_address (
)
INHERITS (address);


--
-- Name: organization_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_address_period (
)
INHERITS (address_period);


--
-- Name: organization_contact; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact (
)
INHERITS (resource_component);


--
-- Name: organization_contact_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_address (
)
INHERITS (address);


--
-- Name: organization_contact_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_address_period (
)
INHERITS (address_period);


--
-- Name: organization_contact_gender; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_gender (
)
INHERITS (cc);


--
-- Name: organization_contact_gender_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_gender_cd (
)
INHERITS (cc_cd);


--
-- Name: organization_contact_gender_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_gender_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: organization_contact_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_name (
)
INHERITS (human_name);


--
-- Name: organization_contact_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_name_period (
)
INHERITS (human_name_period);


--
-- Name: organization_contact_purpose; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_purpose (
)
INHERITS (cc);


--
-- Name: organization_contact_purpose_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_purpose_cd (
)
INHERITS (cc_cd);


--
-- Name: organization_contact_purpose_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_purpose_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: organization_contact_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_telecom (
)
INHERITS (contact);


--
-- Name: organization_contact_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_contact_telecom_period (
)
INHERITS (contact_period);


--
-- Name: organization_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_idn (
)
INHERITS (idn);


--
-- Name: organization_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: organization_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_idn_period (
)
INHERITS (idn_period);


--
-- Name: organization_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_loc (
)
INHERITS (resource_reference);


--
-- Name: organization_part_of; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_part_of (
)
INHERITS (resource_reference);


--
-- Name: organization_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_telecom (
)
INHERITS (contact);


--
-- Name: organization_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_telecom_period (
)
INHERITS (contact_period);


--
-- Name: organization_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_text (
)
INHERITS (narrative);


--
-- Name: organization_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_type (
)
INHERITS (cc);


--
-- Name: organization_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_type_cd (
)
INHERITS (cc_cd);


--
-- Name: organization_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE organization_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: other; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other (
    created date
)
INHERITS (resource);


--
-- Name: other_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_author (
)
INHERITS (resource_reference);


--
-- Name: other_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_code (
)
INHERITS (cc);


--
-- Name: other_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_code_cd (
)
INHERITS (cc_cd);


--
-- Name: other_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: other_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_idn (
)
INHERITS (idn);


--
-- Name: other_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: other_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_idn_period (
)
INHERITS (idn_period);


--
-- Name: other_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_subject (
)
INHERITS (resource_reference);


--
-- Name: other_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE other_text (
)
INHERITS (narrative);


--
-- Name: patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient (
    deceased_boolean boolean,
    multiple_birth_boolean boolean,
    active boolean,
    birth_date timestamp without time zone,
    deceased_date_time timestamp without time zone,
    multiple_birth_integer integer
)
INHERITS (resource);


--
-- Name: patient_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_address (
)
INHERITS (address);


--
-- Name: patient_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_address_period (
)
INHERITS (address_period);


--
-- Name: patient_animal; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal (
)
INHERITS (resource_component);


--
-- Name: patient_animal_breed; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_breed (
)
INHERITS (cc);


--
-- Name: patient_animal_breed_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_breed_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_animal_breed_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_breed_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_animal_gender_status; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_gender_status (
)
INHERITS (cc);


--
-- Name: patient_animal_gender_status_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_gender_status_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_animal_gender_status_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_gender_status_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_animal_species; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_species (
)
INHERITS (cc);


--
-- Name: patient_animal_species_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_species_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_animal_species_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_animal_species_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_care_provider; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_care_provider (
)
INHERITS (resource_reference);


--
-- Name: patient_communication; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_communication (
)
INHERITS (cc);


--
-- Name: patient_communication_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_communication_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_communication_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_communication_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_contact; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact (
)
INHERITS (resource_component);


--
-- Name: patient_contact_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_address (
)
INHERITS (address);


--
-- Name: patient_contact_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_address_period (
)
INHERITS (address_period);


--
-- Name: patient_contact_gender; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_gender (
)
INHERITS (cc);


--
-- Name: patient_contact_gender_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_gender_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_contact_gender_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_gender_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_contact_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_name (
)
INHERITS (human_name);


--
-- Name: patient_contact_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_name_period (
)
INHERITS (human_name_period);


--
-- Name: patient_contact_organization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_organization (
)
INHERITS (resource_reference);


--
-- Name: patient_contact_relationship; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_relationship (
)
INHERITS (cc);


--
-- Name: patient_contact_relationship_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_relationship_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_contact_relationship_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_relationship_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_contact_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_telecom (
)
INHERITS (contact);


--
-- Name: patient_contact_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_contact_telecom_period (
)
INHERITS (contact_period);


--
-- Name: patient_gender; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_gender (
)
INHERITS (cc);


--
-- Name: patient_gender_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_gender_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_gender_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_gender_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_idn (
)
INHERITS (idn);


--
-- Name: patient_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: patient_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_idn_period (
)
INHERITS (idn_period);


--
-- Name: patient_link; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_link (
    type character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: patient_link_other; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_link_other (
)
INHERITS (resource_reference);


--
-- Name: patient_managing_organization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_managing_organization (
)
INHERITS (resource_reference);


--
-- Name: patient_marital_status; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_marital_status (
)
INHERITS (cc);


--
-- Name: patient_marital_status_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_marital_status_cd (
)
INHERITS (cc_cd);


--
-- Name: patient_marital_status_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_marital_status_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: patient_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_name (
)
INHERITS (human_name);


--
-- Name: patient_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_name_period (
)
INHERITS (human_name_period);


--
-- Name: patient_photo; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_photo (
)
INHERITS (attachment);


--
-- Name: patient_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_telecom (
)
INHERITS (contact);


--
-- Name: patient_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_telecom_period (
)
INHERITS (contact_period);


--
-- Name: patient_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE patient_text (
)
INHERITS (narrative);


--
-- Name: practitioner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner (
    birth_date timestamp without time zone
)
INHERITS (resource);


--
-- Name: practitioner_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_address (
)
INHERITS (address);


--
-- Name: practitioner_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_address_period (
)
INHERITS (address_period);


--
-- Name: practitioner_communication; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_communication (
)
INHERITS (cc);


--
-- Name: practitioner_communication_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_communication_cd (
)
INHERITS (cc_cd);


--
-- Name: practitioner_communication_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_communication_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: practitioner_gender; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_gender (
)
INHERITS (cc);


--
-- Name: practitioner_gender_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_gender_cd (
)
INHERITS (cc_cd);


--
-- Name: practitioner_gender_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_gender_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: practitioner_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_idn (
)
INHERITS (idn);


--
-- Name: practitioner_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: practitioner_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_idn_period (
)
INHERITS (idn_period);


--
-- Name: practitioner_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_loc (
)
INHERITS (resource_reference);


--
-- Name: practitioner_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_name (
)
INHERITS (human_name);


--
-- Name: practitioner_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_name_period (
)
INHERITS (human_name_period);


--
-- Name: practitioner_organization; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_organization (
)
INHERITS (resource_reference);


--
-- Name: practitioner_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_period (
)
INHERITS (period);


--
-- Name: practitioner_photo; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_photo (
)
INHERITS (attachment);


--
-- Name: practitioner_qualification; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification (
)
INHERITS (resource_component);


--
-- Name: practitioner_qualification_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification_code (
)
INHERITS (cc);


--
-- Name: practitioner_qualification_code_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification_code_cd (
)
INHERITS (cc_cd);


--
-- Name: practitioner_qualification_code_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification_code_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: practitioner_qualification_issuer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification_issuer (
)
INHERITS (resource_reference);


--
-- Name: practitioner_qualification_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_qualification_period (
)
INHERITS (period);


--
-- Name: practitioner_role; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_role (
)
INHERITS (cc);


--
-- Name: practitioner_role_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_role_cd (
)
INHERITS (cc_cd);


--
-- Name: practitioner_role_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_role_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: practitioner_specialty; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_specialty (
)
INHERITS (cc);


--
-- Name: practitioner_specialty_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_specialty_cd (
)
INHERITS (cc_cd);


--
-- Name: practitioner_specialty_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_specialty_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: practitioner_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_telecom (
)
INHERITS (contact);


--
-- Name: practitioner_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_telecom_period (
)
INHERITS (contact_period);


--
-- Name: practitioner_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE practitioner_text (
)
INHERITS (narrative);


--
-- Name: procedure; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure (
    outcome character varying,
    follow_up character varying,
    notes character varying
)
INHERITS (resource);


--
-- Name: procedure_body_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_body_site (
)
INHERITS (cc);


--
-- Name: procedure_body_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_body_site_cd (
)
INHERITS (cc_cd);


--
-- Name: procedure_body_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_body_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: procedure_complication; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_complication (
)
INHERITS (cc);


--
-- Name: procedure_complication_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_complication_cd (
)
INHERITS (cc_cd);


--
-- Name: procedure_complication_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_complication_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: procedure_date; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_date (
)
INHERITS (period);


--
-- Name: procedure_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_encounter (
)
INHERITS (resource_reference);


--
-- Name: procedure_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_idn (
)
INHERITS (idn);


--
-- Name: procedure_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: procedure_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_idn_period (
)
INHERITS (idn_period);


--
-- Name: procedure_indication; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_indication (
)
INHERITS (cc);


--
-- Name: procedure_indication_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_indication_cd (
)
INHERITS (cc_cd);


--
-- Name: procedure_indication_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_indication_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: procedure_performer; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_performer (
)
INHERITS (resource_component);


--
-- Name: procedure_performer_person; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_performer_person (
)
INHERITS (resource_reference);


--
-- Name: procedure_performer_role; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_performer_role (
)
INHERITS (cc);


--
-- Name: procedure_performer_role_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_performer_role_cd (
)
INHERITS (cc_cd);


--
-- Name: procedure_performer_role_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_performer_role_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: procedure_related_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_related_item (
    type character varying
)
INHERITS (resource_component);


--
-- Name: procedure_related_item_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_related_item_target (
)
INHERITS (resource_reference);


--
-- Name: procedure_report; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_report (
)
INHERITS (resource_reference);


--
-- Name: procedure_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_subject (
)
INHERITS (resource_reference);


--
-- Name: procedure_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_text (
)
INHERITS (narrative);


--
-- Name: procedure_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_type (
)
INHERITS (cc);


--
-- Name: procedure_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_type_cd (
)
INHERITS (cc_cd);


--
-- Name: procedure_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE procedure_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: profile; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile (
    experimental boolean,
    status character varying NOT NULL,
    date timestamp without time zone,
    fhir_version character varying,
    identifier character varying,
    version character varying,
    name character varying NOT NULL,
    publisher character varying,
    description character varying,
    requirements character varying
)
INHERITS (resource);


--
-- Name: profile_code; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_code (
)
INHERITS (cd);


--
-- Name: profile_code_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_code_vs (
)
INHERITS (cd_vs);


--
-- Name: profile_extension_defn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_extension_defn (
    code character varying NOT NULL,
    context_type character varying NOT NULL,
    display character varying,
    context character varying[] NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_mapping; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_mapping (
    identity character varying NOT NULL,
    name character varying,
    comments character varying,
    uri character varying
)
INHERITS (resource_component);


--
-- Name: profile_query; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_query (
    name character varying NOT NULL,
    documentation character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_structure; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure (
    publish boolean,
    type character varying NOT NULL,
    name character varying,
    purpose character varying
)
INHERITS (resource_component);


--
-- Name: profile_structure_element; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element (
    representation character varying[],
    path character varying NOT NULL,
    name character varying
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_definition; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition (
    is_modifier boolean NOT NULL,
    must_support boolean,
    condition character varying[],
    min integer NOT NULL,
    max_length integer,
    short character varying NOT NULL,
    formal character varying NOT NULL,
    comments character varying,
    requirements character varying,
    synonym character varying[],
    max character varying NOT NULL,
    name_reference character varying
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_definition_binding; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition_binding (
    is_extensible boolean NOT NULL,
    conformance character varying,
    name character varying NOT NULL,
    description character varying,
    reference_uri character varying
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_definition_binding_reference_resource; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition_binding_reference_resource (
)
INHERITS (resource_reference);


--
-- Name: profile_structure_element_definition_constraint; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition_constraint (
    severity character varying NOT NULL,
    key character varying NOT NULL,
    name character varying,
    human character varying NOT NULL,
    xpath character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_definition_mapping; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition_mapping (
    identity character varying NOT NULL,
    map character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_definition_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_definition_type (
    aggregation character varying[],
    code character varying NOT NULL,
    profile character varying
)
INHERITS (resource_component);


--
-- Name: profile_structure_element_slicing; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_element_slicing (
    ordered boolean NOT NULL,
    rules character varying NOT NULL,
    discriminator character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_structure_search_param; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_structure_search_param (
    type character varying NOT NULL,
    target character varying[],
    xpath character varying,
    name character varying NOT NULL,
    documentation character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: profile_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_telecom (
)
INHERITS (contact);


--
-- Name: profile_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_telecom_period (
)
INHERITS (contact_period);


--
-- Name: profile_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE profile_text (
)
INHERITS (narrative);


--
-- Name: provenance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance (
    recorded timestamp without time zone NOT NULL,
    integrity_signature character varying,
    policy character varying[]
)
INHERITS (resource);


--
-- Name: provenance_agent; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_agent (
    display character varying,
    reference character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: provenance_agent_role; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_agent_role (
)
INHERITS (cd);


--
-- Name: provenance_agent_role_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_agent_role_vs (
)
INHERITS (cd_vs);


--
-- Name: provenance_agent_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_agent_type (
)
INHERITS (cd);


--
-- Name: provenance_agent_type_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_agent_type_vs (
)
INHERITS (cd_vs);


--
-- Name: provenance_entity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_entity (
    role character varying NOT NULL,
    display character varying,
    reference character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: provenance_entity_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_entity_type (
)
INHERITS (cd);


--
-- Name: provenance_entity_type_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_entity_type_vs (
)
INHERITS (cd_vs);


--
-- Name: provenance_loc; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_loc (
)
INHERITS (resource_reference);


--
-- Name: provenance_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_period (
)
INHERITS (period);


--
-- Name: provenance_reason; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_reason (
)
INHERITS (cc);


--
-- Name: provenance_reason_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_reason_cd (
)
INHERITS (cc_cd);


--
-- Name: provenance_reason_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_reason_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: provenance_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_target (
)
INHERITS (resource_reference);


--
-- Name: provenance_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE provenance_text (
)
INHERITS (narrative);


--
-- Name: query; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE query (
    identifier character varying NOT NULL
)
INHERITS (resource);


--
-- Name: query_response; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE query_response (
    outcome character varying NOT NULL,
    total integer,
    identifier character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: query_response_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE query_response_reference (
)
INHERITS (resource_reference);


--
-- Name: query_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE query_text (
)
INHERITS (narrative);


--
-- Name: questionnaire; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire (
    status character varying NOT NULL,
    authored timestamp without time zone NOT NULL
)
INHERITS (resource);


--
-- Name: questionnaire_author; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_author (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_encounter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_encounter (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_group; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group (
    header character varying,
    text character varying
)
INHERITS (resource_component);


--
-- Name: questionnaire_group_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_name (
)
INHERITS (cc);


--
-- Name: questionnaire_group_name_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_name_cd (
)
INHERITS (cc_cd);


--
-- Name: questionnaire_group_name_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_name_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: questionnaire_group_question; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question (
    answer_boolean boolean,
    answer_date date,
    answer_date_time timestamp without time zone,
    answer_decimal numeric,
    answer_instant timestamp without time zone,
    answer_integer integer,
    answer_string character varying,
    text character varying,
    remarks character varying
)
INHERITS (resource_component);


--
-- Name: questionnaire_group_question_choice; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_choice (
)
INHERITS (cd);


--
-- Name: questionnaire_group_question_choice_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_choice_vs (
)
INHERITS (cd_vs);


--
-- Name: questionnaire_group_question_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_name (
)
INHERITS (cc);


--
-- Name: questionnaire_group_question_name_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_name_cd (
)
INHERITS (cc_cd);


--
-- Name: questionnaire_group_question_name_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_name_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: questionnaire_group_question_options; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_question_options (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_group_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_group_subject (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_idn (
)
INHERITS (idn);


--
-- Name: questionnaire_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: questionnaire_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_idn_period (
)
INHERITS (idn_period);


--
-- Name: questionnaire_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_name (
)
INHERITS (cc);


--
-- Name: questionnaire_name_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_name_cd (
)
INHERITS (cc_cd);


--
-- Name: questionnaire_name_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_name_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: questionnaire_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_source (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_subject (
)
INHERITS (resource_reference);


--
-- Name: questionnaire_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE questionnaire_text (
)
INHERITS (narrative);


--
-- Name: related_person; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person (
)
INHERITS (resource);


--
-- Name: related_person_address; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_address (
)
INHERITS (address);


--
-- Name: related_person_address_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_address_period (
)
INHERITS (address_period);


--
-- Name: related_person_gender; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_gender (
)
INHERITS (cc);


--
-- Name: related_person_gender_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_gender_cd (
)
INHERITS (cc_cd);


--
-- Name: related_person_gender_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_gender_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: related_person_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_idn (
)
INHERITS (idn);


--
-- Name: related_person_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: related_person_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_idn_period (
)
INHERITS (idn_period);


--
-- Name: related_person_name; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_name (
)
INHERITS (human_name);


--
-- Name: related_person_name_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_name_period (
)
INHERITS (human_name_period);


--
-- Name: related_person_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_patient (
)
INHERITS (resource_reference);


--
-- Name: related_person_photo; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_photo (
)
INHERITS (attachment);


--
-- Name: related_person_relationship; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_relationship (
)
INHERITS (cc);


--
-- Name: related_person_relationship_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_relationship_cd (
)
INHERITS (cc_cd);


--
-- Name: related_person_relationship_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_relationship_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: related_person_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_telecom (
)
INHERITS (contact);


--
-- Name: related_person_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_telecom_period (
)
INHERITS (contact_period);


--
-- Name: related_person_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE related_person_text (
)
INHERITS (narrative);


--
-- Name: security_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event (
)
INHERITS (resource);


--
-- Name: security_event_event; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event (
    outcome character varying,
    action character varying,
    date_time timestamp without time zone NOT NULL,
    outcome_desc character varying
)
INHERITS (resource_component);


--
-- Name: security_event_event_subtype; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_subtype (
)
INHERITS (cc);


--
-- Name: security_event_event_subtype_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_subtype_cd (
)
INHERITS (cc_cd);


--
-- Name: security_event_event_subtype_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_subtype_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: security_event_event_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_type (
)
INHERITS (cc);


--
-- Name: security_event_event_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_type_cd (
)
INHERITS (cc_cd);


--
-- Name: security_event_event_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_event_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: security_event_object; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object (
    query bytea,
    lifecycle character varying,
    role character varying,
    type character varying,
    name character varying,
    description character varying
)
INHERITS (resource_component);


--
-- Name: security_event_object_detail; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_detail (
    value bytea NOT NULL,
    type character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: security_event_object_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_idn (
)
INHERITS (idn);


--
-- Name: security_event_object_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: security_event_object_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_idn_period (
)
INHERITS (idn_period);


--
-- Name: security_event_object_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_reference (
)
INHERITS (resource_reference);


--
-- Name: security_event_object_sensitivity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_sensitivity (
)
INHERITS (cc);


--
-- Name: security_event_object_sensitivity_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_sensitivity_cd (
)
INHERITS (cc_cd);


--
-- Name: security_event_object_sensitivity_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_object_sensitivity_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: security_event_participant; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant (
    requestor boolean NOT NULL,
    user_id character varying,
    alt_id character varying,
    name character varying
)
INHERITS (resource_component);


--
-- Name: security_event_participant_media; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_media (
)
INHERITS (cd);


--
-- Name: security_event_participant_media_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_media_vs (
)
INHERITS (cd_vs);


--
-- Name: security_event_participant_network; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_network (
    type character varying,
    identifier character varying
)
INHERITS (resource_component);


--
-- Name: security_event_participant_reference; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_reference (
)
INHERITS (resource_reference);


--
-- Name: security_event_participant_role; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_role (
)
INHERITS (cc);


--
-- Name: security_event_participant_role_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_role_cd (
)
INHERITS (cc_cd);


--
-- Name: security_event_participant_role_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_participant_role_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: security_event_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_source (
    site character varying,
    identifier character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: security_event_source_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_source_type (
)
INHERITS (cd);


--
-- Name: security_event_source_type_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_source_type_vs (
)
INHERITS (cd_vs);


--
-- Name: security_event_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE security_event_text (
)
INHERITS (narrative);


--
-- Name: specimen; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen (
    received_time timestamp without time zone
)
INHERITS (resource);


--
-- Name: specimen_accession_identifier; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_accession_identifier (
)
INHERITS (idn);


--
-- Name: specimen_accession_identifier_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_accession_identifier_assigner (
)
INHERITS (idn_assigner);


--
-- Name: specimen_accession_identifier_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_accession_identifier_period (
)
INHERITS (idn_period);


--
-- Name: specimen_collection; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection (
    collected_date_time timestamp without time zone,
    comment character varying[]
)
INHERITS (resource_component);


--
-- Name: specimen_collection_collected_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_collected_period (
)
INHERITS (period);


--
-- Name: specimen_collection_collector; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_collector (
)
INHERITS (resource_reference);


--
-- Name: specimen_collection_method; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_method (
)
INHERITS (cc);


--
-- Name: specimen_collection_method_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_method_cd (
)
INHERITS (cc_cd);


--
-- Name: specimen_collection_method_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_method_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: specimen_collection_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_quantity (
)
INHERITS (quantity);


--
-- Name: specimen_collection_source_site; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_source_site (
)
INHERITS (cc);


--
-- Name: specimen_collection_source_site_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_source_site_cd (
)
INHERITS (cc_cd);


--
-- Name: specimen_collection_source_site_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_collection_source_site_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: specimen_container; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container (
    description character varying
)
INHERITS (resource_component);


--
-- Name: specimen_container_additive; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_additive (
)
INHERITS (resource_reference);


--
-- Name: specimen_container_capacity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_capacity (
)
INHERITS (quantity);


--
-- Name: specimen_container_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_idn (
)
INHERITS (idn);


--
-- Name: specimen_container_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: specimen_container_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_idn_period (
)
INHERITS (idn_period);


--
-- Name: specimen_container_specimen_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_specimen_quantity (
)
INHERITS (quantity);


--
-- Name: specimen_container_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_type (
)
INHERITS (cc);


--
-- Name: specimen_container_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_type_cd (
)
INHERITS (cc_cd);


--
-- Name: specimen_container_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_container_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: specimen_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_idn (
)
INHERITS (idn);


--
-- Name: specimen_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: specimen_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_idn_period (
)
INHERITS (idn_period);


--
-- Name: specimen_source; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_source (
    relationship character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: specimen_source_target; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_source_target (
)
INHERITS (resource_reference);


--
-- Name: specimen_subject; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_subject (
)
INHERITS (resource_reference);


--
-- Name: specimen_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_text (
)
INHERITS (narrative);


--
-- Name: specimen_treatment; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_treatment (
    description character varying
)
INHERITS (resource_component);


--
-- Name: specimen_treatment_additive; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_treatment_additive (
)
INHERITS (resource_reference);


--
-- Name: specimen_treatment_procedure; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_treatment_procedure (
)
INHERITS (cc);


--
-- Name: specimen_treatment_procedure_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_treatment_procedure_cd (
)
INHERITS (cc_cd);


--
-- Name: specimen_treatment_procedure_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_treatment_procedure_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: specimen_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_type (
)
INHERITS (cc);


--
-- Name: specimen_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_type_cd (
)
INHERITS (cc_cd);


--
-- Name: specimen_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE specimen_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: substance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance (
    description character varying
)
INHERITS (resource);


--
-- Name: substance_ingredient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_ingredient (
)
INHERITS (resource_component);


--
-- Name: substance_ingredient_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_ingredient_quantity (
)
INHERITS (ratio);


--
-- Name: substance_ingredient_quantity_denominator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_ingredient_quantity_denominator (
)
INHERITS (ratio_denominator);


--
-- Name: substance_ingredient_quantity_numerator; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_ingredient_quantity_numerator (
)
INHERITS (ratio_numerator);


--
-- Name: substance_ingredient_substance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_ingredient_substance (
)
INHERITS (resource_reference);


--
-- Name: substance_instance; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_instance (
    expiry timestamp without time zone
)
INHERITS (resource_component);


--
-- Name: substance_instance_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_instance_idn (
)
INHERITS (idn);


--
-- Name: substance_instance_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_instance_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: substance_instance_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_instance_idn_period (
)
INHERITS (idn_period);


--
-- Name: substance_instance_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_instance_quantity (
)
INHERITS (quantity);


--
-- Name: substance_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_text (
)
INHERITS (narrative);


--
-- Name: substance_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_type (
)
INHERITS (cc);


--
-- Name: substance_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_type_cd (
)
INHERITS (cc_cd);


--
-- Name: substance_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE substance_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: supply; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply (
    status character varying
)
INHERITS (resource);


--
-- Name: supply_dispense; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense (
    status character varying
)
INHERITS (resource_component);


--
-- Name: supply_dispense_destination; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_destination (
)
INHERITS (resource_reference);


--
-- Name: supply_dispense_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_idn (
)
INHERITS (idn);


--
-- Name: supply_dispense_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: supply_dispense_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_idn_period (
)
INHERITS (idn_period);


--
-- Name: supply_dispense_quantity; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_quantity (
)
INHERITS (quantity);


--
-- Name: supply_dispense_receiver; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_receiver (
)
INHERITS (resource_reference);


--
-- Name: supply_dispense_supplied_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_supplied_item (
)
INHERITS (resource_reference);


--
-- Name: supply_dispense_supplier; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_supplier (
)
INHERITS (resource_reference);


--
-- Name: supply_dispense_type; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_type (
)
INHERITS (cc);


--
-- Name: supply_dispense_type_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_type_cd (
)
INHERITS (cc_cd);


--
-- Name: supply_dispense_type_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_type_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: supply_dispense_when_handed_over; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_when_handed_over (
)
INHERITS (period);


--
-- Name: supply_dispense_when_prepared; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_dispense_when_prepared (
)
INHERITS (period);


--
-- Name: supply_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_idn (
)
INHERITS (idn);


--
-- Name: supply_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: supply_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_idn_period (
)
INHERITS (idn_period);


--
-- Name: supply_kind; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_kind (
)
INHERITS (cc);


--
-- Name: supply_kind_cd; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_kind_cd (
)
INHERITS (cc_cd);


--
-- Name: supply_kind_cd_vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_kind_cd_vs (
)
INHERITS (cc_cd_vs);


--
-- Name: supply_ordered_item; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_ordered_item (
)
INHERITS (resource_reference);


--
-- Name: supply_patient; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_patient (
)
INHERITS (resource_reference);


--
-- Name: supply_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE supply_text (
)
INHERITS (narrative);


--
-- Name: view_adverse_reaction; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_adverse_reaction AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM adverse_reaction_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM adverse_reaction_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM adverse_reaction_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM adverse_reaction_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM adverse_reaction_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM adverse_reaction_recorder t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS recorder,
            t1.date,
            t1.did_not_occur_flag AS "didNotOccurFlag"
           FROM adverse_reaction t1) t_1;


--
-- Name: view_alert; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_alert AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM alert_category_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM alert_category_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM alert_category t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS category,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM alert_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM alert_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM alert_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM alert_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM alert_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM alert_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.note,
            t1.status
           FROM alert t1) t_1;


--
-- Name: view_allergy_intolerance; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_allergy_intolerance AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM allergy_intolerance_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM allergy_intolerance_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM allergy_intolerance_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM allergy_intolerance_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM allergy_intolerance_substance t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS substance,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM allergy_intolerance_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM allergy_intolerance_sensitivity_test t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "sensitivityTest",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM allergy_intolerance_recorder t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS recorder,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM allergy_intolerance_reaction t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS reaction,
            t1.status,
            t1.sensitivity_type AS "sensitivityType",
            t1.criticality,
            t1.recorded_date AS "recordedDate"
           FROM allergy_intolerance t1) t_1;


--
-- Name: view_care_plan; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_care_plan AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM care_plan_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM care_plan_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS period,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM care_plan_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM care_plan_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM care_plan_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM care_plan_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM care_plan_concern t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS concern,
            t1.notes,
            t1.status,
            t1.modified
           FROM care_plan t1) t_1;


--
-- Name: view_composition; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_composition AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM composition_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM composition_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM composition_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM composition_class_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM composition_class_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM composition_class t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS class,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM composition_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM composition_confidentiality_vs t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS "valueSet",
                            t2.version,
                            t2.display,
                            t2.code,
                            t2."primary",
                            t2.system
                           FROM composition_confidentiality t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS confidentiality,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM composition_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM composition_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM composition_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM composition_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM composition_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM composition_custodian t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS custodian,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM composition_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.title,
            t1.status,
            t1.date
           FROM composition t1) t_1;


--
-- Name: view_concept_map; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_concept_map AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM concept_map_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM concept_map_target t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS target,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM concept_map_source t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS source,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM concept_map_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM concept_map_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.version,
            t1.publisher,
            t1.name,
            t1.identifier,
            t1.description,
            t1.copyright,
            t1.status,
            t1.date,
            t1.experimental
           FROM concept_map t1) t_1;


--
-- Name: view_condition; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_condition AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM condition_severity_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM condition_severity_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM condition_severity t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS severity,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM condition_code_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM condition_code_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM condition_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM condition_certainty_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM condition_certainty_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM condition_certainty t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS certainty,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM condition_category_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM condition_category_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM condition_category t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS category,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM condition_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            NULL::unknown AS "onsetAge",
            NULL::unknown AS "abatementAge",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM condition_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM condition_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM condition_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM condition_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM condition_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM condition_asserter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS asserter,
            t1.notes,
            t1.status,
            t1.abatement_boolean AS "abatementBoolean",
            t1.onset_date AS "onsetDate",
            t1.date_asserted AS "dateAsserted",
            t1.abatement_date AS "abatementDate"
           FROM condition t1) t_1;


--
-- Name: view_conformance; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_conformance AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM conformance_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM conformance_profile t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS profile,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM conformance_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM conformance_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.fhir_version AS "fhirVersion",
            t1.version,
            t1.publisher,
            t1.name,
            t1.identifier,
            t1.description,
            t1.status,
            t1.format,
            t1.date,
            t1.experimental,
            t1.accept_unknown AS "acceptUnknown"
           FROM conformance t1) t_1;


--
-- Name: view_device; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_device AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM device_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM device_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM device_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM device_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM device_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM device_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM device_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM device_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM device_owner t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS owner,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM device_loc t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS location,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM device_contact_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM device_contact t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS contact,
            t1.version,
            t1.udi,
            t1.model,
            t1.manufacturer,
            t1.lot_number AS "lotNumber",
            t1.url,
            t1.expiry
           FROM device t1) t_1;


--
-- Name: view_device_observation_report; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_device_observation_report AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM device_observation_report_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM device_observation_report_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM device_observation_report_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM device_observation_report_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM device_observation_report_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM device_observation_report_source t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS source,
            t1.instant
           FROM device_observation_report t1) t_1;


--
-- Name: view_diagnostic_order; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_diagnostic_order AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM diagnostic_order_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM diagnostic_order_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM diagnostic_order_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM diagnostic_order_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_order_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_order_specimen t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS specimen,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_order_orderer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS orderer,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_order_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            t1.clinical_notes AS "clinicalNotes",
            t1.status,
            t1.priority
           FROM diagnostic_order t1) t_1;


--
-- Name: view_diagnostic_report; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_diagnostic_report AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM diagnostic_report_service_category_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM diagnostic_report_service_category_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM diagnostic_report_service_category t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "serviceCategory",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM diagnostic_report_name_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM diagnostic_report_name_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM diagnostic_report_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM diagnostic_report_coded_diagnosis_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM diagnostic_report_coded_diagnosis_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM diagnostic_report_coded_diagnosis t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "codedDiagnosis",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM diagnostic_report_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM diagnostic_report_diagnostic_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "diagnosticPeriod",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM diagnostic_report_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM diagnostic_report_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM diagnostic_report_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_specimen t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS specimen,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_result t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS result,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_request_detail t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "requestDetail",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_performer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS performer,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM diagnostic_report_imaging_study t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "imagingStudy",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM diagnostic_report_presented_form t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "presentedForm",
            t1.conclusion,
            t1.status,
            t1.issued,
            t1.diagnostic_date_time AS "diagnosticDateTime"
           FROM diagnostic_report t1) t_1;


--
-- Name: view_document_manifest; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_document_manifest AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_manifest_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_manifest_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_manifest_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_manifest_confidentiality_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_manifest_confidentiality_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_manifest_confidentiality t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS confidentiality,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM document_manifest_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM document_manifest_master_identifier_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM document_manifest_master_identifier_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM document_manifest_master_identifier t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "masterIdentifier",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM document_manifest_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM document_manifest_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM document_manifest_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_manifest_supercedes t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS supercedes,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_manifest_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_manifest_recipient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS recipient,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_manifest_content t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS content,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_manifest_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.description,
            t1.status,
            t1.created,
            t1.source
           FROM document_manifest t1) t_1;


--
-- Name: view_document_reference; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_document_reference AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_reference_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_reference_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_reference_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_reference_doc_status_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_reference_doc_status_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_reference_doc_status t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "docStatus",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_reference_confidentiality_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_reference_confidentiality_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_reference_confidentiality t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS confidentiality,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM document_reference_class_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM document_reference_class_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM document_reference_class t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS class,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM document_reference_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM document_reference_master_identifier_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM document_reference_master_identifier_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM document_reference_master_identifier t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "masterIdentifier",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM document_reference_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM document_reference_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM document_reference_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_reference_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_reference_custodian t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS custodian,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_reference_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM document_reference_authenticator t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS authenticator,
            t1.hash,
            t1.description,
            t1.indexed,
            t1.status,
            t1.primary_language AS "primaryLanguage",
            t1.mime_type AS "mimeType",
            t1.created,
            t1.size,
            t1.policy_manager AS "policyManager",
            t1.location,
            t1.format
           FROM document_reference t1) t_1;


--
-- Name: view_encounter; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_encounter AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM encounter_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM encounter_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM encounter_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM encounter_reason_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM encounter_reason_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM encounter_reason t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS reason,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM encounter_priority_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM encounter_priority_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM encounter_priority t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS priority,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM encounter_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM encounter_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS period,
            NULL::unknown AS length,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM encounter_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM encounter_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM encounter_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM encounter_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM encounter_service_provider t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "serviceProvider",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM encounter_part_of t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "partOf",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM encounter_indication t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS indication,
            t1.status,
            t1.class
           FROM encounter t1) t_1;


--
-- Name: view_family_history; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_family_history AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM family_history_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM family_history_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM family_history_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM family_history_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM family_history_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            t1.note
           FROM family_history t1) t_1;


--
-- Name: view_group; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_group AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM group_code_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM group_code_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM group_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM group_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM group_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM group_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM group_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM group_member t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS member,
            t1.name,
            t1.type,
            t1.quantity,
            t1.actual
           FROM "group" t1) t_1;


--
-- Name: view_imaging_study; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_imaging_study AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM imaging_study_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM imaging_study_procedure_vs t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS "valueSet",
                            t2.version,
                            t2.display,
                            t2.code,
                            t2."primary",
                            t2.system
                           FROM imaging_study_procedure t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS procedure,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM imaging_study_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM imaging_study_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM imaging_study_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM imaging_study_accession_no_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM imaging_study_accession_no_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM imaging_study_accession_no t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "accessionNo",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imaging_study_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imaging_study_referrer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS referrer,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imaging_study_order t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "order",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imaging_study_interpreter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS interpreter,
            t1.uid,
            t1.description,
            t1.clinical_information AS "clinicalInformation",
            t1.modality,
            t1.availability,
            t1.date_time AS "dateTime",
            t1.number_of_series AS "numberOfSeries",
            t1.number_of_instances AS "numberOfInstances",
            t1.url
           FROM imaging_study t1) t_1;


--
-- Name: view_immunization; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_immunization AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM imm_vaccine_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM imm_vaccine_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM imm_vaccine_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "vaccineType",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM imm_site_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM imm_site_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM imm_site t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS site,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM imm_route_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM imm_route_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM imm_route t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS route,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM imm_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.units,
                            t2.code,
                            t2.comparator,
                            t2.system,
                            t2.value
                           FROM imm_dose_quantity t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "doseQuantity",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM imm_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM imm_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM imm_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_requester t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS requester,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_performer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS performer,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_manufacturer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS manufacturer,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_loc t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS location,
            t1.lot_number AS "lotNumber",
            t1.date,
            t1.reported,
            t1.refused_indicator AS "refusedIndicator",
            t1.expiration_date AS "expirationDate"
           FROM imm t1) t_1;


--
-- Name: view_immunization_recommendation; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_immunization_recommendation AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM imm_rec_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM imm_rec_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM imm_rec_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM imm_rec_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM imm_rec_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject
           FROM imm_rec t1) t_1;


--
-- Name: view_list; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_list AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM list_empty_reason_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM list_empty_reason_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM list_empty_reason t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "emptyReason",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM list_code_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM list_code_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM list_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM list_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM list_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM list_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM list_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM list_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM list_source t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS source,
            t1.mode,
            t1.date,
            t1.ordered
           FROM list t1) t_1;


--
-- Name: view_location; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_location AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM loc_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM loc_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM loc_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM loc_physical_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM loc_physical_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM loc_physical_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "physicalType",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM loc_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM loc_address_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.zip,
                            t2.text,
                            t2.state,
                            t2.line,
                            t2.country,
                            t2.city
                           FROM loc_address t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS address,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM loc_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM loc_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM loc_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM loc_part_of t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "partOf",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM loc_managing_organization t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "managingOrganization",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM loc_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM loc_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.name,
            t1.description,
            t1.status,
            t1.mode
           FROM loc t1) t_1;


--
-- Name: view_media; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_media AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM media_view_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM media_view_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM media_view t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS view,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM media_subtype_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM media_subtype_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM media_subtype t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subtype,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM media_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM media_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM media_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM media_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM media_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM media_operator t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS operator,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM media_content t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS content,
            t1.device_name AS "deviceName",
            t1.type,
            t1.date_time AS "dateTime",
            t1.width,
            t1.length,
            t1.height,
            t1.frames
           FROM media t1) t_1;


--
-- Name: view_medication; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_medication AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM med_code_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM med_code_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM med_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM med_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_manufacturer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS manufacturer,
            t1.name,
            t1.kind,
            t1.is_brand AS "isBrand"
           FROM med t1) t_1;


--
-- Name: view_medication_administration; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_medication_administration AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM med_adm_reason_not_given_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM med_adm_reason_not_given_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM med_adm_reason_not_given t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonNotGiven",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM med_adm_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM med_adm_when_given t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "whenGiven",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM med_adm_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM med_adm_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM med_adm_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_prs t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS prescription,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_practitioner t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS practitioner,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_med t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS medication,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_adm_device t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS device,
            t1.status,
            t1.was_not_given AS "wasNotGiven"
           FROM med_adm t1) t_1;


--
-- Name: view_medication_dispense; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_medication_dispense AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM med_disp_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM med_disp_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM med_disp_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM med_disp_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_disp_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_disp_dispenser t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS dispenser,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_disp_authorizing_prescription t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "authorizingPrescription",
            t1.status
           FROM med_disp t1) t_1;


--
-- Name: view_medication_prescription; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_medication_prescription AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM med_prs_reason_codeable_concept_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM med_prs_reason_codeable_concept_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM med_prs_reason_codeable_concept t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonCodeableConcept",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM med_prs_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM med_prs_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM med_prs_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM med_prs_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_prs_reason_resource_reference t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonResourceReference",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_prs_prescriber t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS prescriber,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_prs_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_prs_med t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS medication,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_prs_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            t1.status,
            t1.date_written AS "dateWritten"
           FROM med_prs t1) t_1;


--
-- Name: view_medication_statement; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_medication_statement AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM med_st_reason_not_given_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM med_st_reason_not_given_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM med_st_reason_not_given t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonNotGiven",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM med_st_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM med_st_when_given t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "whenGiven",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM med_st_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM med_st_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM med_st_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_st_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_st_med t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS medication,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM med_st_device t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS device,
            t1.was_not_given AS "wasNotGiven"
           FROM med_st t1) t_1;


--
-- Name: view_message_header; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_message_header AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM message_header_reason_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM message_header_reason_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM message_header_reason t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS reason,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM message_header_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM message_header_event_vs t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS "valueSet",
                            t2.version,
                            t2.display,
                            t2.code,
                            t2."primary",
                            t2.system
                           FROM message_header_event t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS event,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM message_header_responsible t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS responsible,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM message_header_receiver t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS receiver,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM message_header_enterer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS enterer,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM message_header_data t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS data,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM message_header_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.identifier,
            t1."timestamp"
           FROM message_header t1) t_1;


--
-- Name: view_observation; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_observation AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM observation_value_codeable_concept_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM observation_value_codeable_concept_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM observation_value_codeable_concept t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valueCodeableConcept",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM observation_name_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM observation_name_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM observation_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM observation_method_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM observation_method_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM observation_method t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS method,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM observation_interpretation_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM observation_interpretation_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM observation_interpretation t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS interpretation,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM observation_body_site_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM observation_body_site_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM observation_body_site t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "bodySite",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.units,
                                            t3.code,
                                            t3.comparator,
                                            t3.system,
                                            t3.value
                                           FROM observation_value_sampled_data_origin t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS origin,
                            t2.data,
                            t2.dimensions,
                            t2.upper_limit AS "upperLimit",
                            t2.period,
                            t2.lower_limit AS "lowerLimit",
                            t2.factor
                           FROM observation_value_sampled_data t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valueSampledData",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM observation_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM observation_value_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valuePeriod",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM observation_applies_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "appliesPeriod",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.units,
                                            t3.code,
                                            t3.comparator,
                                            t3.system,
                                            t3.value
                                           FROM observation_value_ratio_numerator t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS numerator,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.units,
                                            t3.code,
                                            t3.comparator,
                                            t3.system,
                                            t3.value
                                           FROM observation_value_ratio_denominator t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS denominator
                           FROM observation_value_ratio t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valueRatio",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.units,
                            t2.code,
                            t2.comparator,
                            t2.system,
                            t2.value
                           FROM observation_value_quantity t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valueQuantity",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM observation_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM observation_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM observation_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM observation_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM observation_specimen t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS specimen,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM observation_performer t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS performer,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM observation_value_attachment t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "valueAttachment",
            t1.value_string AS "valueString",
            t1.comments,
            t1.issued,
            t1.status,
            t1.reliability,
            t1.applies_date_time AS "appliesDateTime"
           FROM observation t1) t_1;


--
-- Name: view_operation_outcome; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_operation_outcome AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM operation_outcome_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text
           FROM operation_outcome t1) t_1;


--
-- Name: view_order; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_order AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM order_reason_codeable_concept_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM order_reason_codeable_concept_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM order_reason_codeable_concept t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonCodeableConcept",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM order_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM order_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM order_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM order_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_target t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS target,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_source t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS source,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_reason_resource_reference t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "reasonResourceReference",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_detail t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS detail,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_authority t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS authority,
            t1.date
           FROM "order" t1) t_1;


--
-- Name: view_order_response; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_order_response AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM order_response_authority_codeable_concept_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM order_response_authority_codeable_concept_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM order_response_authority_codeable_concept t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "authorityCodeableConcept",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM order_response_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM order_response_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM order_response_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM order_response_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_response_who t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS who,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_response_request t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS request,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_response_fulfillment t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS fulfillment,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM order_response_authority_resource_reference t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "authorityResourceReference",
            t1.description,
            t1.code,
            t1.date
           FROM order_response t1) t_1;


--
-- Name: view_organization; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_organization AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM organization_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM organization_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM organization_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM organization_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM organization_address_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.zip,
                            t2.text,
                            t2.state,
                            t2.line,
                            t2.country,
                            t2.city
                           FROM organization_address t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS address,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM organization_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM organization_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM organization_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM organization_part_of t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "partOf",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM organization_loc t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS location,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM organization_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM organization_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.name,
            t1.active
           FROM organization t1) t_1;


--
-- Name: view_other; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_other AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM other_code_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM other_code_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM other_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM other_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM other_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM other_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM other_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM other_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM other_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.created
           FROM other t1) t_1;


--
-- Name: view_patient; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_patient AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM patient_marital_status_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM patient_marital_status_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM patient_marital_status t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "maritalStatus",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM patient_gender_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM patient_gender_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM patient_gender t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS gender,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM patient_communication_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM patient_communication_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM patient_communication t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS communication,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM patient_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM patient_address_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.zip,
                            t2.text,
                            t2.state,
                            t2.line,
                            t2.country,
                            t2.city
                           FROM patient_address t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS address,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM patient_name_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.text,
                            t2.suffix,
                            t2.prefix,
                            t2.given,
                            t2.family,
                            t2.use
                           FROM patient_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM patient_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM patient_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM patient_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM patient_managing_organization t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "managingOrganization",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM patient_care_provider t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "careProvider",
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM patient_photo t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS photo,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM patient_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM patient_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.deceased_date_time AS "deceasedDateTime",
            t1.birth_date AS "birthDate",
            t1.multiple_birth_integer AS "multipleBirthInteger",
            t1.multiple_birth_boolean AS "multipleBirthBoolean",
            t1.deceased_boolean AS "deceasedBoolean",
            t1.active
           FROM patient t1) t_1;


--
-- Name: view_practitioner; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_practitioner AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM practitioner_specialty_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM practitioner_specialty_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM practitioner_specialty t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS specialty,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM practitioner_role_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM practitioner_role_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM practitioner_role t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS role,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM practitioner_gender_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM practitioner_gender_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM practitioner_gender t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS gender,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM practitioner_communication_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM practitioner_communication_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM practitioner_communication t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS communication,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM practitioner_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM practitioner_address_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.zip,
                            t2.text,
                            t2.state,
                            t2.line,
                            t2.country,
                            t2.city
                           FROM practitioner_address t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS address,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM practitioner_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS period,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM practitioner_name_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.text,
                            t2.suffix,
                            t2.prefix,
                            t2.given,
                            t2.family,
                            t2.use
                           FROM practitioner_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM practitioner_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM practitioner_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM practitioner_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM practitioner_organization t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS organization,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM practitioner_loc t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS location,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM practitioner_photo t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS photo,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM practitioner_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM practitioner_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.birth_date AS "birthDate"
           FROM practitioner t1) t_1;


--
-- Name: view_procedure; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_procedure AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM procedure_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM procedure_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM procedure_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM procedure_indication_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM procedure_indication_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM procedure_indication t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS indication,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM procedure_complication_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM procedure_complication_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM procedure_complication t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS complication,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM procedure_body_site_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM procedure_body_site_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM procedure_body_site t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "bodySite",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM procedure_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM procedure_date t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS date,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM procedure_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM procedure_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM procedure_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM procedure_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM procedure_report t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS report,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM procedure_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            t1.outcome,
            t1.notes,
            t1.follow_up AS "followUp"
           FROM procedure t1) t_1;


--
-- Name: view_profile; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_profile AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM profile_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM profile_code_vs t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS "valueSet",
                            t2.version,
                            t2.display,
                            t2.code,
                            t2."primary",
                            t2.system
                           FROM profile_code t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS code,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM profile_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM profile_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.fhir_version AS "fhirVersion",
            t1.version,
            t1.requirements,
            t1.publisher,
            t1.name,
            t1.identifier,
            t1.description,
            t1.status,
            t1.date,
            t1.experimental
           FROM profile t1) t_1;


--
-- Name: view_provenance; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_provenance AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM provenance_reason_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM provenance_reason_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM provenance_reason t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS reason,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM provenance_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.start,
                            t2."end"
                           FROM provenance_period t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS period,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM provenance_target t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS target,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM provenance_loc t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS location,
            t1.integrity_signature AS "integritySignature",
            t1.recorded,
            t1.policy
           FROM provenance t1) t_1;


--
-- Name: view_query; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_query AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM query_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            t1.identifier
           FROM query t1) t_1;


--
-- Name: view_questionnaire; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_questionnaire AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM questionnaire_name_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM questionnaire_name_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM questionnaire_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM questionnaire_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM questionnaire_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM questionnaire_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM questionnaire_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM questionnaire_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM questionnaire_source t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS source,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM questionnaire_encounter t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS encounter,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM questionnaire_author t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS author,
            t1.status,
            t1.authored
           FROM questionnaire t1) t_1;


--
-- Name: view_related_person; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_related_person AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM related_person_relationship_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM related_person_relationship_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM related_person_relationship t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS relationship,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM related_person_gender_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM related_person_gender_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM related_person_gender t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS gender,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM related_person_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM related_person_address_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.zip,
                            t2.text,
                            t2.state,
                            t2.line,
                            t2.country,
                            t2.city
                           FROM related_person_address t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS address,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM related_person_name_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.text,
                            t2.suffix,
                            t2.prefix,
                            t2.given,
                            t2.family,
                            t2.use
                           FROM related_person_name t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS name,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM related_person_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM related_person_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM related_person_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM related_person_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT t2.hash,
                            t2.data,
                            t2.title,
                            t2.language,
                            t2.content_type AS "contentType",
                            t2.size,
                            t2.url
                           FROM related_person_photo t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS photo,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM related_person_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM related_person_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom
           FROM related_person t1) t_1;


--
-- Name: view_security_event; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_security_event AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM security_event_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text
           FROM security_event t1) t_1;


--
-- Name: view_specimen; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_specimen AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM specimen_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM specimen_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM specimen_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM specimen_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM specimen_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM specimen_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM specimen_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM specimen_accession_identifier_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM specimen_accession_identifier_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM specimen_accession_identifier t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "accessionIdentifier",
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM specimen_subject t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS subject,
            t1.received_time AS "receivedTime"
           FROM specimen t1) t_1;


--
-- Name: view_substance; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_substance AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM substance_type_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM substance_type_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM substance_type t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS type,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM substance_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            t1.description
           FROM substance t1) t_1;


--
-- Name: view_supply; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_supply AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_3.*, true)), true) AS array_to_json
                                   FROM ( SELECT ( SELECT array_to_json(array_agg(row_to_json(t_4.*, true)), true) AS array_to_json
                                                   FROM ( SELECT t4.reference,
                                                            t4.display
                                                           FROM supply_kind_cd_vs t4
                                                          WHERE ((t4.resource_id = t1.id) AND (t4.parent_id = t3.id))) t_4) AS "valueSet",
                                            t3.version,
                                            t3.display,
                                            t3.code,
                                            t3."primary",
                                            t3.system
                                           FROM supply_kind_cd t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS coding,
                            t2.text
                           FROM supply_kind t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS kind,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM supply_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM supply_idn_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.reference,
                                            t3.display
                                           FROM supply_idn_assigner t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS assigner,
                            t2.value,
                            t2.label,
                            t2.use,
                            t2.system
                           FROM supply_idn t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS identifier,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM supply_patient t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS patient,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.reference,
                            t2.display
                           FROM supply_ordered_item t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS "orderedItem",
            t1.status
           FROM supply t1) t_1;


--
-- Name: vs; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs (
    experimental boolean,
    extensible boolean,
    status character varying NOT NULL,
    date timestamp without time zone,
    publisher character varying,
    name character varying NOT NULL,
    copyright character varying,
    description character varying NOT NULL,
    version character varying,
    identifier character varying
)
INHERITS (resource);


--
-- Name: vs_telecom; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_telecom (
)
INHERITS (contact);


--
-- Name: vs_telecom_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_telecom_period (
)
INHERITS (contact_period);


--
-- Name: vs_text; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_text (
)
INHERITS (narrative);


--
-- Name: view_value_set; Type: VIEW; Schema: fhir; Owner: -
--

CREATE VIEW view_value_set AS
 SELECT t_1.id,
    row_to_json(t_1.*, true) AS json
   FROM ( SELECT t1.id,
            ( SELECT row_to_json(t_2.*, true) AS row_to_json
                   FROM ( SELECT t2.div,
                            t2.status
                           FROM vs_text t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS text,
            ( SELECT array_to_json(array_agg(row_to_json(t_2.*, true)), true) AS array_to_json
                   FROM ( SELECT ( SELECT row_to_json(t_3.*, true) AS row_to_json
                                   FROM ( SELECT t3.start,
                                            t3."end"
                                           FROM vs_telecom_period t3
                                          WHERE ((t3.resource_id = t1.id) AND (t3.parent_id = t2.id))) t_3) AS period,
                            t2.use,
                            t2.value,
                            t2.system
                           FROM vs_telecom t2
                          WHERE ((t2.resource_id = t1.id) AND (t2.parent_id = t1.id))) t_2) AS telecom,
            t1.version,
            t1.publisher,
            t1.name,
            t1.identifier,
            t1.description,
            t1.copyright,
            t1.status,
            t1.date,
            t1.extensible,
            t1.experimental
           FROM vs t1) t_1;


--
-- Name: vs_compose; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_compose (
    import character varying[]
)
INHERITS (resource_component);


--
-- Name: vs_compose_include; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_compose_include (
    code character varying[],
    version character varying,
    system character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: vs_compose_include_filter; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_compose_include_filter (
    op character varying NOT NULL,
    property character varying NOT NULL,
    value character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: vs_define; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_define (
    case_sensitive boolean,
    version character varying,
    system character varying NOT NULL
)
INHERITS (resource_component);


--
-- Name: vs_define_concept; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_define_concept (
    abstract boolean,
    code character varying NOT NULL,
    definition character varying,
    display character varying
)
INHERITS (resource_component);


--
-- Name: vs_expansion; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_expansion (
    "timestamp" timestamp without time zone NOT NULL
)
INHERITS (resource_component);


--
-- Name: vs_expansion_contains; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_expansion_contains (
    code character varying,
    display character varying,
    system character varying
)
INHERITS (resource_component);


--
-- Name: vs_expansion_idn; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_expansion_idn (
)
INHERITS (idn);


--
-- Name: vs_expansion_idn_assigner; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_expansion_idn_assigner (
)
INHERITS (idn_assigner);


--
-- Name: vs_expansion_idn_period; Type: TABLE; Schema: fhir; Owner: -; Tablespace: 
--

CREATE TABLE vs_expansion_idn_period (
)
INHERITS (idn_period);


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction ALTER COLUMN _type SET DEFAULT 'adverse_reaction'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_exposure ALTER COLUMN _type SET DEFAULT 'adverse_reaction_exposure'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_exposure_substance ALTER COLUMN _type SET DEFAULT 'adverse_reaction_exposure_substance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_idn ALTER COLUMN _type SET DEFAULT 'adverse_reaction_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_idn_assigner ALTER COLUMN _type SET DEFAULT 'adverse_reaction_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_idn_period ALTER COLUMN _type SET DEFAULT 'adverse_reaction_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_recorder ALTER COLUMN _type SET DEFAULT 'adverse_reaction_recorder'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_subject ALTER COLUMN _type SET DEFAULT 'adverse_reaction_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_symptom ALTER COLUMN _type SET DEFAULT 'adverse_reaction_symptom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_symptom_code ALTER COLUMN _type SET DEFAULT 'adverse_reaction_symptom_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_symptom_code_cd ALTER COLUMN _type SET DEFAULT 'adverse_reaction_symptom_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_symptom_code_cd_vs ALTER COLUMN _type SET DEFAULT 'adverse_reaction_symptom_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY adverse_reaction_text ALTER COLUMN _type SET DEFAULT 'adverse_reaction_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert ALTER COLUMN _type SET DEFAULT 'alert'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_author ALTER COLUMN _type SET DEFAULT 'alert_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_category ALTER COLUMN _type SET DEFAULT 'alert_category'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_category_cd ALTER COLUMN _type SET DEFAULT 'alert_category_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_category_cd_vs ALTER COLUMN _type SET DEFAULT 'alert_category_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_idn ALTER COLUMN _type SET DEFAULT 'alert_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_idn_assigner ALTER COLUMN _type SET DEFAULT 'alert_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_idn_period ALTER COLUMN _type SET DEFAULT 'alert_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_subject ALTER COLUMN _type SET DEFAULT 'alert_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY alert_text ALTER COLUMN _type SET DEFAULT 'alert_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance ALTER COLUMN _type SET DEFAULT 'allergy_intolerance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_idn ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_idn_assigner ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_idn_period ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_reaction ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_reaction'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_recorder ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_recorder'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_sensitivity_test ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_sensitivity_test'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_subject ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_substance ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_substance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY allergy_intolerance_text ALTER COLUMN _type SET DEFAULT 'allergy_intolerance_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan ALTER COLUMN _type SET DEFAULT 'care_plan'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity ALTER COLUMN _type SET DEFAULT 'care_plan_activity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_action_resulting ALTER COLUMN _type SET DEFAULT 'care_plan_activity_action_resulting'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_detail ALTER COLUMN _type SET DEFAULT 'care_plan_activity_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_code ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_code_cd ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_code_cd_vs ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_daily_amount ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_daily_amount'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_loc ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_performer ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_performer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_product ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_product'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_quantity ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_timing_period ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_timing_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_timing_schedule ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_timing_schedule'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_timing_schedule_event ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_timing_schedule_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_activity_simple_timing_schedule_repeat ALTER COLUMN _type SET DEFAULT 'care_plan_activity_simple_timing_schedule_repeat'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_concern ALTER COLUMN _type SET DEFAULT 'care_plan_concern'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_goal ALTER COLUMN _type SET DEFAULT 'care_plan_goal'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_goal_concern ALTER COLUMN _type SET DEFAULT 'care_plan_goal_concern'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_idn ALTER COLUMN _type SET DEFAULT 'care_plan_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_idn_assigner ALTER COLUMN _type SET DEFAULT 'care_plan_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_idn_period ALTER COLUMN _type SET DEFAULT 'care_plan_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_participant ALTER COLUMN _type SET DEFAULT 'care_plan_participant'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_participant_member ALTER COLUMN _type SET DEFAULT 'care_plan_participant_member'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_participant_role ALTER COLUMN _type SET DEFAULT 'care_plan_participant_role'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_participant_role_cd ALTER COLUMN _type SET DEFAULT 'care_plan_participant_role_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_participant_role_cd_vs ALTER COLUMN _type SET DEFAULT 'care_plan_participant_role_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_patient ALTER COLUMN _type SET DEFAULT 'care_plan_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_period ALTER COLUMN _type SET DEFAULT 'care_plan_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY care_plan_text ALTER COLUMN _type SET DEFAULT 'care_plan_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition ALTER COLUMN _type SET DEFAULT 'composition'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_attester ALTER COLUMN _type SET DEFAULT 'composition_attester'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_attester_party ALTER COLUMN _type SET DEFAULT 'composition_attester_party'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_author ALTER COLUMN _type SET DEFAULT 'composition_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_class ALTER COLUMN _type SET DEFAULT 'composition_class'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_class_cd ALTER COLUMN _type SET DEFAULT 'composition_class_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_class_cd_vs ALTER COLUMN _type SET DEFAULT 'composition_class_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_confidentiality ALTER COLUMN _type SET DEFAULT 'composition_confidentiality'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_confidentiality_vs ALTER COLUMN _type SET DEFAULT 'composition_confidentiality_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_custodian ALTER COLUMN _type SET DEFAULT 'composition_custodian'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_encounter ALTER COLUMN _type SET DEFAULT 'composition_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event ALTER COLUMN _type SET DEFAULT 'composition_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event_code ALTER COLUMN _type SET DEFAULT 'composition_event_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event_code_cd ALTER COLUMN _type SET DEFAULT 'composition_event_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event_code_cd_vs ALTER COLUMN _type SET DEFAULT 'composition_event_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event_detail ALTER COLUMN _type SET DEFAULT 'composition_event_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_event_period ALTER COLUMN _type SET DEFAULT 'composition_event_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_idn ALTER COLUMN _type SET DEFAULT 'composition_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_idn_assigner ALTER COLUMN _type SET DEFAULT 'composition_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_idn_period ALTER COLUMN _type SET DEFAULT 'composition_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section ALTER COLUMN _type SET DEFAULT 'composition_section'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section_code ALTER COLUMN _type SET DEFAULT 'composition_section_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section_code_cd ALTER COLUMN _type SET DEFAULT 'composition_section_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section_code_cd_vs ALTER COLUMN _type SET DEFAULT 'composition_section_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section_content ALTER COLUMN _type SET DEFAULT 'composition_section_content'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_section_subject ALTER COLUMN _type SET DEFAULT 'composition_section_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_subject ALTER COLUMN _type SET DEFAULT 'composition_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_text ALTER COLUMN _type SET DEFAULT 'composition_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_type ALTER COLUMN _type SET DEFAULT 'composition_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_type_cd ALTER COLUMN _type SET DEFAULT 'composition_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY composition_type_cd_vs ALTER COLUMN _type SET DEFAULT 'composition_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map ALTER COLUMN _type SET DEFAULT 'concept_map'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_concept ALTER COLUMN _type SET DEFAULT 'concept_map_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_concept_depends_on ALTER COLUMN _type SET DEFAULT 'concept_map_concept_depends_on'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_concept_map ALTER COLUMN _type SET DEFAULT 'concept_map_concept_map'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_source ALTER COLUMN _type SET DEFAULT 'concept_map_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_target ALTER COLUMN _type SET DEFAULT 'concept_map_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_telecom ALTER COLUMN _type SET DEFAULT 'concept_map_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_telecom_period ALTER COLUMN _type SET DEFAULT 'concept_map_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY concept_map_text ALTER COLUMN _type SET DEFAULT 'concept_map_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition ALTER COLUMN _type SET DEFAULT 'condition'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_asserter ALTER COLUMN _type SET DEFAULT 'condition_asserter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_category ALTER COLUMN _type SET DEFAULT 'condition_category'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_category_cd ALTER COLUMN _type SET DEFAULT 'condition_category_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_category_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_category_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_certainty ALTER COLUMN _type SET DEFAULT 'condition_certainty'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_certainty_cd ALTER COLUMN _type SET DEFAULT 'condition_certainty_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_certainty_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_certainty_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_code ALTER COLUMN _type SET DEFAULT 'condition_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_code_cd ALTER COLUMN _type SET DEFAULT 'condition_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_code_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_encounter ALTER COLUMN _type SET DEFAULT 'condition_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_evidence ALTER COLUMN _type SET DEFAULT 'condition_evidence'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_evidence_code ALTER COLUMN _type SET DEFAULT 'condition_evidence_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_evidence_code_cd ALTER COLUMN _type SET DEFAULT 'condition_evidence_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_evidence_code_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_evidence_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_evidence_detail ALTER COLUMN _type SET DEFAULT 'condition_evidence_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_idn ALTER COLUMN _type SET DEFAULT 'condition_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_idn_assigner ALTER COLUMN _type SET DEFAULT 'condition_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_idn_period ALTER COLUMN _type SET DEFAULT 'condition_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_loc ALTER COLUMN _type SET DEFAULT 'condition_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_loc_code ALTER COLUMN _type SET DEFAULT 'condition_loc_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_loc_code_cd ALTER COLUMN _type SET DEFAULT 'condition_loc_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_loc_code_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_loc_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_related_item ALTER COLUMN _type SET DEFAULT 'condition_related_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_related_item_code ALTER COLUMN _type SET DEFAULT 'condition_related_item_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_related_item_code_cd ALTER COLUMN _type SET DEFAULT 'condition_related_item_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_related_item_code_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_related_item_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_related_item_target ALTER COLUMN _type SET DEFAULT 'condition_related_item_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_severity ALTER COLUMN _type SET DEFAULT 'condition_severity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_severity_cd ALTER COLUMN _type SET DEFAULT 'condition_severity_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_severity_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_severity_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_stage ALTER COLUMN _type SET DEFAULT 'condition_stage'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_stage_assessment ALTER COLUMN _type SET DEFAULT 'condition_stage_assessment'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_stage_summary ALTER COLUMN _type SET DEFAULT 'condition_stage_summary'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_stage_summary_cd ALTER COLUMN _type SET DEFAULT 'condition_stage_summary_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_stage_summary_cd_vs ALTER COLUMN _type SET DEFAULT 'condition_stage_summary_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_subject ALTER COLUMN _type SET DEFAULT 'condition_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY condition_text ALTER COLUMN _type SET DEFAULT 'condition_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance ALTER COLUMN _type SET DEFAULT 'conformance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_document ALTER COLUMN _type SET DEFAULT 'conformance_document'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_document_profile ALTER COLUMN _type SET DEFAULT 'conformance_document_profile'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_implementation ALTER COLUMN _type SET DEFAULT 'conformance_implementation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging ALTER COLUMN _type SET DEFAULT 'conformance_messaging'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_code ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_code_vs ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_code_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_protocol ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_protocol'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_protocol_vs ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_protocol_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_request ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_request'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_messaging_event_response ALTER COLUMN _type SET DEFAULT 'conformance_messaging_event_response'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_profile ALTER COLUMN _type SET DEFAULT 'conformance_profile'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest ALTER COLUMN _type SET DEFAULT 'conformance_rest'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_operation ALTER COLUMN _type SET DEFAULT 'conformance_rest_operation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_query ALTER COLUMN _type SET DEFAULT 'conformance_rest_query'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_resource ALTER COLUMN _type SET DEFAULT 'conformance_rest_resource'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_resource_operation ALTER COLUMN _type SET DEFAULT 'conformance_rest_resource_operation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_resource_profile ALTER COLUMN _type SET DEFAULT 'conformance_rest_resource_profile'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_resource_search_param ALTER COLUMN _type SET DEFAULT 'conformance_rest_resource_search_param'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_security ALTER COLUMN _type SET DEFAULT 'conformance_rest_security'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_security_certificate ALTER COLUMN _type SET DEFAULT 'conformance_rest_security_certificate'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_security_service ALTER COLUMN _type SET DEFAULT 'conformance_rest_security_service'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_security_service_cd ALTER COLUMN _type SET DEFAULT 'conformance_rest_security_service_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_rest_security_service_cd_vs ALTER COLUMN _type SET DEFAULT 'conformance_rest_security_service_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_software ALTER COLUMN _type SET DEFAULT 'conformance_software'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_telecom ALTER COLUMN _type SET DEFAULT 'conformance_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_telecom_period ALTER COLUMN _type SET DEFAULT 'conformance_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY conformance_text ALTER COLUMN _type SET DEFAULT 'conformance_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device ALTER COLUMN _type SET DEFAULT 'device'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_contact ALTER COLUMN _type SET DEFAULT 'device_contact'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_contact_period ALTER COLUMN _type SET DEFAULT 'device_contact_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_idn ALTER COLUMN _type SET DEFAULT 'device_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_idn_assigner ALTER COLUMN _type SET DEFAULT 'device_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_idn_period ALTER COLUMN _type SET DEFAULT 'device_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_loc ALTER COLUMN _type SET DEFAULT 'device_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report ALTER COLUMN _type SET DEFAULT 'device_observation_report'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_idn ALTER COLUMN _type SET DEFAULT 'device_observation_report_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_idn_assigner ALTER COLUMN _type SET DEFAULT 'device_observation_report_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_idn_period ALTER COLUMN _type SET DEFAULT 'device_observation_report_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_source ALTER COLUMN _type SET DEFAULT 'device_observation_report_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_subject ALTER COLUMN _type SET DEFAULT 'device_observation_report_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_text ALTER COLUMN _type SET DEFAULT 'device_observation_report_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel_code ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel_code_cd ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel_code_cd_vs ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel_metric ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel_metric'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_channel_metric_observa ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_channel_metric_observation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_code ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_code_cd ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_observation_report_virtual_device_code_cd_vs ALTER COLUMN _type SET DEFAULT 'device_observation_report_virtual_device_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_owner ALTER COLUMN _type SET DEFAULT 'device_owner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_patient ALTER COLUMN _type SET DEFAULT 'device_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_text ALTER COLUMN _type SET DEFAULT 'device_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_type ALTER COLUMN _type SET DEFAULT 'device_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_type_cd ALTER COLUMN _type SET DEFAULT 'device_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY device_type_cd_vs ALTER COLUMN _type SET DEFAULT 'device_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order ALTER COLUMN _type SET DEFAULT 'diagnostic_order'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_encounter ALTER COLUMN _type SET DEFAULT 'diagnostic_order_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_event ALTER COLUMN _type SET DEFAULT 'diagnostic_order_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_event_actor ALTER COLUMN _type SET DEFAULT 'diagnostic_order_event_actor'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_event_description ALTER COLUMN _type SET DEFAULT 'diagnostic_order_event_description'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_event_description_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_order_event_description_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_event_description_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_order_event_description_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_idn ALTER COLUMN _type SET DEFAULT 'diagnostic_order_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_idn_assigner ALTER COLUMN _type SET DEFAULT 'diagnostic_order_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_idn_period ALTER COLUMN _type SET DEFAULT 'diagnostic_order_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_body_site ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_body_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_body_site_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_body_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_body_site_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_body_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_code ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_code_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_code_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_item_specimen ALTER COLUMN _type SET DEFAULT 'diagnostic_order_item_specimen'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_orderer ALTER COLUMN _type SET DEFAULT 'diagnostic_order_orderer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_specimen ALTER COLUMN _type SET DEFAULT 'diagnostic_order_specimen'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_subject ALTER COLUMN _type SET DEFAULT 'diagnostic_order_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_order_text ALTER COLUMN _type SET DEFAULT 'diagnostic_order_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report ALTER COLUMN _type SET DEFAULT 'diagnostic_report'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_coded_diagnosis ALTER COLUMN _type SET DEFAULT 'diagnostic_report_coded_diagnosis'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_coded_diagnosis_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_report_coded_diagnosis_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_coded_diagnosis_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_report_coded_diagnosis_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_diagnostic_period ALTER COLUMN _type SET DEFAULT 'diagnostic_report_diagnostic_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_idn ALTER COLUMN _type SET DEFAULT 'diagnostic_report_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_idn_assigner ALTER COLUMN _type SET DEFAULT 'diagnostic_report_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_idn_period ALTER COLUMN _type SET DEFAULT 'diagnostic_report_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_image ALTER COLUMN _type SET DEFAULT 'diagnostic_report_image'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_image_link ALTER COLUMN _type SET DEFAULT 'diagnostic_report_image_link'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_imaging_study ALTER COLUMN _type SET DEFAULT 'diagnostic_report_imaging_study'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_name ALTER COLUMN _type SET DEFAULT 'diagnostic_report_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_name_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_report_name_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_name_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_report_name_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_performer ALTER COLUMN _type SET DEFAULT 'diagnostic_report_performer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_presented_form ALTER COLUMN _type SET DEFAULT 'diagnostic_report_presented_form'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_request_detail ALTER COLUMN _type SET DEFAULT 'diagnostic_report_request_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_result ALTER COLUMN _type SET DEFAULT 'diagnostic_report_result'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_service_category ALTER COLUMN _type SET DEFAULT 'diagnostic_report_service_category'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_service_category_cd ALTER COLUMN _type SET DEFAULT 'diagnostic_report_service_category_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_service_category_cd_vs ALTER COLUMN _type SET DEFAULT 'diagnostic_report_service_category_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_specimen ALTER COLUMN _type SET DEFAULT 'diagnostic_report_specimen'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_subject ALTER COLUMN _type SET DEFAULT 'diagnostic_report_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY diagnostic_report_text ALTER COLUMN _type SET DEFAULT 'diagnostic_report_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest ALTER COLUMN _type SET DEFAULT 'document_manifest'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_author ALTER COLUMN _type SET DEFAULT 'document_manifest_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_confidentiality ALTER COLUMN _type SET DEFAULT 'document_manifest_confidentiality'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_confidentiality_cd ALTER COLUMN _type SET DEFAULT 'document_manifest_confidentiality_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_confidentiality_cd_vs ALTER COLUMN _type SET DEFAULT 'document_manifest_confidentiality_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_content ALTER COLUMN _type SET DEFAULT 'document_manifest_content'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_idn ALTER COLUMN _type SET DEFAULT 'document_manifest_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_idn_assigner ALTER COLUMN _type SET DEFAULT 'document_manifest_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_idn_period ALTER COLUMN _type SET DEFAULT 'document_manifest_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_master_identifier ALTER COLUMN _type SET DEFAULT 'document_manifest_master_identifier'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_master_identifier_assigner ALTER COLUMN _type SET DEFAULT 'document_manifest_master_identifier_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_master_identifier_period ALTER COLUMN _type SET DEFAULT 'document_manifest_master_identifier_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_recipient ALTER COLUMN _type SET DEFAULT 'document_manifest_recipient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_subject ALTER COLUMN _type SET DEFAULT 'document_manifest_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_supercedes ALTER COLUMN _type SET DEFAULT 'document_manifest_supercedes'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_text ALTER COLUMN _type SET DEFAULT 'document_manifest_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_type ALTER COLUMN _type SET DEFAULT 'document_manifest_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_type_cd ALTER COLUMN _type SET DEFAULT 'document_manifest_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_manifest_type_cd_vs ALTER COLUMN _type SET DEFAULT 'document_manifest_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference ALTER COLUMN _type SET DEFAULT 'document_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_authenticator ALTER COLUMN _type SET DEFAULT 'document_reference_authenticator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_author ALTER COLUMN _type SET DEFAULT 'document_reference_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_class ALTER COLUMN _type SET DEFAULT 'document_reference_class'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_class_cd ALTER COLUMN _type SET DEFAULT 'document_reference_class_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_class_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_class_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_confidentiality ALTER COLUMN _type SET DEFAULT 'document_reference_confidentiality'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_confidentiality_cd ALTER COLUMN _type SET DEFAULT 'document_reference_confidentiality_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_confidentiality_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_confidentiality_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context ALTER COLUMN _type SET DEFAULT 'document_reference_context'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_event ALTER COLUMN _type SET DEFAULT 'document_reference_context_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_event_cd ALTER COLUMN _type SET DEFAULT 'document_reference_context_event_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_event_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_context_event_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_facility_type ALTER COLUMN _type SET DEFAULT 'document_reference_context_facility_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_facility_type_cd ALTER COLUMN _type SET DEFAULT 'document_reference_context_facility_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_facility_type_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_context_facility_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_context_period ALTER COLUMN _type SET DEFAULT 'document_reference_context_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_custodian ALTER COLUMN _type SET DEFAULT 'document_reference_custodian'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_doc_status ALTER COLUMN _type SET DEFAULT 'document_reference_doc_status'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_doc_status_cd ALTER COLUMN _type SET DEFAULT 'document_reference_doc_status_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_doc_status_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_doc_status_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_idn ALTER COLUMN _type SET DEFAULT 'document_reference_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_idn_assigner ALTER COLUMN _type SET DEFAULT 'document_reference_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_idn_period ALTER COLUMN _type SET DEFAULT 'document_reference_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_master_identifier ALTER COLUMN _type SET DEFAULT 'document_reference_master_identifier'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_master_identifier_assigner ALTER COLUMN _type SET DEFAULT 'document_reference_master_identifier_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_master_identifier_period ALTER COLUMN _type SET DEFAULT 'document_reference_master_identifier_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_relates_to ALTER COLUMN _type SET DEFAULT 'document_reference_relates_to'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_relates_to_target ALTER COLUMN _type SET DEFAULT 'document_reference_relates_to_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_service ALTER COLUMN _type SET DEFAULT 'document_reference_service'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_service_parameter ALTER COLUMN _type SET DEFAULT 'document_reference_service_parameter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_service_type ALTER COLUMN _type SET DEFAULT 'document_reference_service_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_service_type_cd ALTER COLUMN _type SET DEFAULT 'document_reference_service_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_service_type_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_service_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_subject ALTER COLUMN _type SET DEFAULT 'document_reference_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_text ALTER COLUMN _type SET DEFAULT 'document_reference_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_type ALTER COLUMN _type SET DEFAULT 'document_reference_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_type_cd ALTER COLUMN _type SET DEFAULT 'document_reference_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY document_reference_type_cd_vs ALTER COLUMN _type SET DEFAULT 'document_reference_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter ALTER COLUMN _type SET DEFAULT 'encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_accomodation ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_accomodation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_accomodation_bed ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_accomodation_bed'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_accomodation_period ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_accomodation_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_admit_source ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_admit_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_admit_source_cd ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_admit_source_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_admit_source_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_admit_source_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_destination ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_destination'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_diet ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_diet'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_diet_cd ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_diet_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_diet_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_diet_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_discharge_diagnosis ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_discharge_diagnosis'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_discharge_disposition ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_discharge_disposition'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_discharge_disposition_cd ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_discharge_disposition_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_discharge_disposition_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_discharge_disposition_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_origin ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_origin'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_period ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_pre_admission_identifier ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_pre_admission_identifier'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_pre_admission_identifier_assigner ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_pre_admission_identifier_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_pre_admission_identifier_period ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_pre_admission_identifier_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_arrangement ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_arrangement'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_arrangement_cd ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_arrangement_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_arrangement_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_arrangement_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_courtesy ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_courtesy'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_courtesy_cd ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_courtesy_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_hospitalization_special_courtesy_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_hospitalization_special_courtesy_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_idn ALTER COLUMN _type SET DEFAULT 'encounter_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_idn_assigner ALTER COLUMN _type SET DEFAULT 'encounter_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_idn_period ALTER COLUMN _type SET DEFAULT 'encounter_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_indication ALTER COLUMN _type SET DEFAULT 'encounter_indication'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_loc ALTER COLUMN _type SET DEFAULT 'encounter_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_loc_loc ALTER COLUMN _type SET DEFAULT 'encounter_loc_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_loc_period ALTER COLUMN _type SET DEFAULT 'encounter_loc_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_part_of ALTER COLUMN _type SET DEFAULT 'encounter_part_of'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_participant ALTER COLUMN _type SET DEFAULT 'encounter_participant'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_participant_individual ALTER COLUMN _type SET DEFAULT 'encounter_participant_individual'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_participant_type ALTER COLUMN _type SET DEFAULT 'encounter_participant_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_participant_type_cd ALTER COLUMN _type SET DEFAULT 'encounter_participant_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_participant_type_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_participant_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_period ALTER COLUMN _type SET DEFAULT 'encounter_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_priority ALTER COLUMN _type SET DEFAULT 'encounter_priority'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_priority_cd ALTER COLUMN _type SET DEFAULT 'encounter_priority_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_priority_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_priority_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_reason ALTER COLUMN _type SET DEFAULT 'encounter_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_reason_cd ALTER COLUMN _type SET DEFAULT 'encounter_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_service_provider ALTER COLUMN _type SET DEFAULT 'encounter_service_provider'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_subject ALTER COLUMN _type SET DEFAULT 'encounter_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_text ALTER COLUMN _type SET DEFAULT 'encounter_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_type ALTER COLUMN _type SET DEFAULT 'encounter_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_type_cd ALTER COLUMN _type SET DEFAULT 'encounter_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY encounter_type_cd_vs ALTER COLUMN _type SET DEFAULT 'encounter_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history ALTER COLUMN _type SET DEFAULT 'family_history'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_idn ALTER COLUMN _type SET DEFAULT 'family_history_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_idn_assigner ALTER COLUMN _type SET DEFAULT 'family_history_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_idn_period ALTER COLUMN _type SET DEFAULT 'family_history_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation ALTER COLUMN _type SET DEFAULT 'family_history_relation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_born_period ALTER COLUMN _type SET DEFAULT 'family_history_relation_born_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_onset_range ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_onset_range'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_onset_range_high ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_onset_range_high'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_onset_range_low ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_onset_range_low'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_outcome ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_outcome'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_outcome_cd ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_outcome_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_outcome_cd_vs ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_outcome_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_type ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_type_cd ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_condition_type_cd_vs ALTER COLUMN _type SET DEFAULT 'family_history_relation_condition_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_deceased_range ALTER COLUMN _type SET DEFAULT 'family_history_relation_deceased_range'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_deceased_range_high ALTER COLUMN _type SET DEFAULT 'family_history_relation_deceased_range_high'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_deceased_range_low ALTER COLUMN _type SET DEFAULT 'family_history_relation_deceased_range_low'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_relationship ALTER COLUMN _type SET DEFAULT 'family_history_relation_relationship'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_relationship_cd ALTER COLUMN _type SET DEFAULT 'family_history_relation_relationship_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_relation_relationship_cd_vs ALTER COLUMN _type SET DEFAULT 'family_history_relation_relationship_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_subject ALTER COLUMN _type SET DEFAULT 'family_history_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY family_history_text ALTER COLUMN _type SET DEFAULT 'family_history_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY "group" ALTER COLUMN _type SET DEFAULT 'group'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic ALTER COLUMN _type SET DEFAULT 'group_characteristic'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_code ALTER COLUMN _type SET DEFAULT 'group_characteristic_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_code_cd ALTER COLUMN _type SET DEFAULT 'group_characteristic_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_code_cd_vs ALTER COLUMN _type SET DEFAULT 'group_characteristic_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_codeable_concept ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_quantity ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_range ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_range'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_range_high ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_range_high'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_characteristic_value_range_low ALTER COLUMN _type SET DEFAULT 'group_characteristic_value_range_low'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_code ALTER COLUMN _type SET DEFAULT 'group_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_code_cd ALTER COLUMN _type SET DEFAULT 'group_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_code_cd_vs ALTER COLUMN _type SET DEFAULT 'group_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_idn ALTER COLUMN _type SET DEFAULT 'group_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_idn_assigner ALTER COLUMN _type SET DEFAULT 'group_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_idn_period ALTER COLUMN _type SET DEFAULT 'group_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_member ALTER COLUMN _type SET DEFAULT 'group_member'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY group_text ALTER COLUMN _type SET DEFAULT 'group_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study ALTER COLUMN _type SET DEFAULT 'imaging_study'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_accession_no ALTER COLUMN _type SET DEFAULT 'imaging_study_accession_no'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_accession_no_assigner ALTER COLUMN _type SET DEFAULT 'imaging_study_accession_no_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_accession_no_period ALTER COLUMN _type SET DEFAULT 'imaging_study_accession_no_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_idn ALTER COLUMN _type SET DEFAULT 'imaging_study_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_idn_assigner ALTER COLUMN _type SET DEFAULT 'imaging_study_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_idn_period ALTER COLUMN _type SET DEFAULT 'imaging_study_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_interpreter ALTER COLUMN _type SET DEFAULT 'imaging_study_interpreter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_order ALTER COLUMN _type SET DEFAULT 'imaging_study_order'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_procedure ALTER COLUMN _type SET DEFAULT 'imaging_study_procedure'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_procedure_vs ALTER COLUMN _type SET DEFAULT 'imaging_study_procedure_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_referrer ALTER COLUMN _type SET DEFAULT 'imaging_study_referrer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_series ALTER COLUMN _type SET DEFAULT 'imaging_study_series'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_series_body_site ALTER COLUMN _type SET DEFAULT 'imaging_study_series_body_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_series_body_site_vs ALTER COLUMN _type SET DEFAULT 'imaging_study_series_body_site_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_series_instance ALTER COLUMN _type SET DEFAULT 'imaging_study_series_instance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_series_instance_attachment ALTER COLUMN _type SET DEFAULT 'imaging_study_series_instance_attachment'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_subject ALTER COLUMN _type SET DEFAULT 'imaging_study_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imaging_study_text ALTER COLUMN _type SET DEFAULT 'imaging_study_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm ALTER COLUMN _type SET DEFAULT 'imm'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_dose_quantity ALTER COLUMN _type SET DEFAULT 'imm_dose_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation ALTER COLUMN _type SET DEFAULT 'imm_explanation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_reason ALTER COLUMN _type SET DEFAULT 'imm_explanation_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_reason_cd ALTER COLUMN _type SET DEFAULT 'imm_explanation_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_explanation_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_refusal_reason ALTER COLUMN _type SET DEFAULT 'imm_explanation_refusal_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_refusal_reason_cd ALTER COLUMN _type SET DEFAULT 'imm_explanation_refusal_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_explanation_refusal_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_explanation_refusal_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_idn ALTER COLUMN _type SET DEFAULT 'imm_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_idn_assigner ALTER COLUMN _type SET DEFAULT 'imm_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_idn_period ALTER COLUMN _type SET DEFAULT 'imm_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_loc ALTER COLUMN _type SET DEFAULT 'imm_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_manufacturer ALTER COLUMN _type SET DEFAULT 'imm_manufacturer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_performer ALTER COLUMN _type SET DEFAULT 'imm_performer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_reaction ALTER COLUMN _type SET DEFAULT 'imm_reaction'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_reaction_detail ALTER COLUMN _type SET DEFAULT 'imm_reaction_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec ALTER COLUMN _type SET DEFAULT 'imm_rec'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_idn ALTER COLUMN _type SET DEFAULT 'imm_rec_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_idn_assigner ALTER COLUMN _type SET DEFAULT 'imm_rec_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_idn_period ALTER COLUMN _type SET DEFAULT 'imm_rec_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_date_criterion ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_date_criterion'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_date_criterion_code ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_date_criterion_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_date_criterion_code_cd ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_date_criterion_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_date_criterion_code_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_date_criterion_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_forecast_status ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_forecast_status'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_forecast_status_cd ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_forecast_status_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_forecast_status_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_forecast_status_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_protocol ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_protocol'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_protocol_authority ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_protocol_authority'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_supporting_immunization ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_supporting_immunization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_supporting_patient_information ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_supporting_patient_information'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_vaccine_type ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_vaccine_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_vaccine_type_cd ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_vaccine_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_recommendation_vaccine_type_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_rec_recommendation_vaccine_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_subject ALTER COLUMN _type SET DEFAULT 'imm_rec_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_rec_text ALTER COLUMN _type SET DEFAULT 'imm_rec_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_requester ALTER COLUMN _type SET DEFAULT 'imm_requester'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_route ALTER COLUMN _type SET DEFAULT 'imm_route'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_route_cd ALTER COLUMN _type SET DEFAULT 'imm_route_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_route_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_route_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_site ALTER COLUMN _type SET DEFAULT 'imm_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_site_cd ALTER COLUMN _type SET DEFAULT 'imm_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_site_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_subject ALTER COLUMN _type SET DEFAULT 'imm_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_text ALTER COLUMN _type SET DEFAULT 'imm_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_authority ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_authority'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status_cd ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status_reason ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status_reason_cd ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_status_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_status_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_target ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_target_cd ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_target_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccination_protocol_dose_target_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_vaccination_protocol_dose_target_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccine_type ALTER COLUMN _type SET DEFAULT 'imm_vaccine_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccine_type_cd ALTER COLUMN _type SET DEFAULT 'imm_vaccine_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY imm_vaccine_type_cd_vs ALTER COLUMN _type SET DEFAULT 'imm_vaccine_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list ALTER COLUMN _type SET DEFAULT 'list'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_code ALTER COLUMN _type SET DEFAULT 'list_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_code_cd ALTER COLUMN _type SET DEFAULT 'list_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_code_cd_vs ALTER COLUMN _type SET DEFAULT 'list_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_empty_reason ALTER COLUMN _type SET DEFAULT 'list_empty_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_empty_reason_cd ALTER COLUMN _type SET DEFAULT 'list_empty_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_empty_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'list_empty_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_entry ALTER COLUMN _type SET DEFAULT 'list_entry'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_entry_flag ALTER COLUMN _type SET DEFAULT 'list_entry_flag'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_entry_flag_cd ALTER COLUMN _type SET DEFAULT 'list_entry_flag_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_entry_flag_cd_vs ALTER COLUMN _type SET DEFAULT 'list_entry_flag_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_entry_item ALTER COLUMN _type SET DEFAULT 'list_entry_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_idn ALTER COLUMN _type SET DEFAULT 'list_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_idn_assigner ALTER COLUMN _type SET DEFAULT 'list_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_idn_period ALTER COLUMN _type SET DEFAULT 'list_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_source ALTER COLUMN _type SET DEFAULT 'list_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_subject ALTER COLUMN _type SET DEFAULT 'list_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY list_text ALTER COLUMN _type SET DEFAULT 'list_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc ALTER COLUMN _type SET DEFAULT 'loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_address ALTER COLUMN _type SET DEFAULT 'loc_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_address_period ALTER COLUMN _type SET DEFAULT 'loc_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_idn ALTER COLUMN _type SET DEFAULT 'loc_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_idn_assigner ALTER COLUMN _type SET DEFAULT 'loc_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_idn_period ALTER COLUMN _type SET DEFAULT 'loc_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_managing_organization ALTER COLUMN _type SET DEFAULT 'loc_managing_organization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_part_of ALTER COLUMN _type SET DEFAULT 'loc_part_of'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_physical_type ALTER COLUMN _type SET DEFAULT 'loc_physical_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_physical_type_cd ALTER COLUMN _type SET DEFAULT 'loc_physical_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_physical_type_cd_vs ALTER COLUMN _type SET DEFAULT 'loc_physical_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_position ALTER COLUMN _type SET DEFAULT 'loc_position'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_telecom ALTER COLUMN _type SET DEFAULT 'loc_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_telecom_period ALTER COLUMN _type SET DEFAULT 'loc_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_text ALTER COLUMN _type SET DEFAULT 'loc_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_type ALTER COLUMN _type SET DEFAULT 'loc_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_type_cd ALTER COLUMN _type SET DEFAULT 'loc_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY loc_type_cd_vs ALTER COLUMN _type SET DEFAULT 'loc_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med ALTER COLUMN _type SET DEFAULT 'med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm ALTER COLUMN _type SET DEFAULT 'med_adm'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_device ALTER COLUMN _type SET DEFAULT 'med_adm_device'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage ALTER COLUMN _type SET DEFAULT 'med_adm_dosage'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_as_needed_codeable_concept ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_as_needed_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_as_needed_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_as_needed_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_as_needed_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_as_needed_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_max_dose_per_period ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_max_dose_per_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_max_dose_per_period_denominator ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_max_dose_per_period_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_max_dose_per_period_numerator ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_max_dose_per_period_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_method ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_method_cd ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_method_cd_vs ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_quantity ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_rate ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_rate'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_rate_denominator ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_rate_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_rate_numerator ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_rate_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_route ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_route'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_route_cd ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_route_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_route_cd_vs ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_route_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_site ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_site_cd ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_site_cd_vs ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_dosage_timing_period ALTER COLUMN _type SET DEFAULT 'med_adm_dosage_timing_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_encounter ALTER COLUMN _type SET DEFAULT 'med_adm_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_idn ALTER COLUMN _type SET DEFAULT 'med_adm_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_idn_assigner ALTER COLUMN _type SET DEFAULT 'med_adm_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_idn_period ALTER COLUMN _type SET DEFAULT 'med_adm_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_med ALTER COLUMN _type SET DEFAULT 'med_adm_med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_patient ALTER COLUMN _type SET DEFAULT 'med_adm_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_practitioner ALTER COLUMN _type SET DEFAULT 'med_adm_practitioner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_prs ALTER COLUMN _type SET DEFAULT 'med_adm_prs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_reason_not_given ALTER COLUMN _type SET DEFAULT 'med_adm_reason_not_given'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_reason_not_given_cd ALTER COLUMN _type SET DEFAULT 'med_adm_reason_not_given_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_reason_not_given_cd_vs ALTER COLUMN _type SET DEFAULT 'med_adm_reason_not_given_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_text ALTER COLUMN _type SET DEFAULT 'med_adm_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_adm_when_given ALTER COLUMN _type SET DEFAULT 'med_adm_when_given'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_code ALTER COLUMN _type SET DEFAULT 'med_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_code_cd ALTER COLUMN _type SET DEFAULT 'med_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_code_cd_vs ALTER COLUMN _type SET DEFAULT 'med_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp ALTER COLUMN _type SET DEFAULT 'med_disp'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_authorizing_prescription ALTER COLUMN _type SET DEFAULT 'med_disp_authorizing_prescription'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense ALTER COLUMN _type SET DEFAULT 'med_disp_dispense'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_destination ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_destination'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_additional_instructions ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_additional_instructions'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_additional_instructions_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_additional_instructions_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_additional_instructions_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_additional_instructions_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_as_needed_codeable_concept ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_as_needed_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_as_needed_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_as_needed_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_max_dose_per_period ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_max_dose_per_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_max_dose_per_period_denominator ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_max_dose_per_period_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_max_dose_per_period_numerator ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_max_dose_per_period_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_method ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_method_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_method_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_quantity ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_rate ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_rate'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_rate_denominator ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_rate_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_rate_numerator ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_rate_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_route ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_route'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_route_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_route_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_route_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_route_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_site ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_site_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_site_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_timing_period ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_timing_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_timing_schedule ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_timing_schedule'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_timing_schedule_event ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_timing_schedule_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_dosage_timing_schedule_repeat ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_dosage_timing_schedule_repeat'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_idn ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_idn_assigner ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_idn_period ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_med ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_quantity ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_receiver ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_receiver'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_type ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_type_cd ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispense_type_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_dispense_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_dispenser ALTER COLUMN _type SET DEFAULT 'med_disp_dispenser'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_idn ALTER COLUMN _type SET DEFAULT 'med_disp_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_idn_assigner ALTER COLUMN _type SET DEFAULT 'med_disp_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_idn_period ALTER COLUMN _type SET DEFAULT 'med_disp_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_patient ALTER COLUMN _type SET DEFAULT 'med_disp_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution ALTER COLUMN _type SET DEFAULT 'med_disp_substitution'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_reason ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_reason_cd ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_responsible_party ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_responsible_party'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_type ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_type_cd ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_substitution_type_cd_vs ALTER COLUMN _type SET DEFAULT 'med_disp_substitution_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_disp_text ALTER COLUMN _type SET DEFAULT 'med_disp_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_manufacturer ALTER COLUMN _type SET DEFAULT 'med_manufacturer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package ALTER COLUMN _type SET DEFAULT 'med_package'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_container ALTER COLUMN _type SET DEFAULT 'med_package_container'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_container_cd ALTER COLUMN _type SET DEFAULT 'med_package_container_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_container_cd_vs ALTER COLUMN _type SET DEFAULT 'med_package_container_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_content ALTER COLUMN _type SET DEFAULT 'med_package_content'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_content_amount ALTER COLUMN _type SET DEFAULT 'med_package_content_amount'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_package_content_item ALTER COLUMN _type SET DEFAULT 'med_package_content_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product ALTER COLUMN _type SET DEFAULT 'med_product'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_form ALTER COLUMN _type SET DEFAULT 'med_product_form'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_form_cd ALTER COLUMN _type SET DEFAULT 'med_product_form_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_form_cd_vs ALTER COLUMN _type SET DEFAULT 'med_product_form_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_ingredient ALTER COLUMN _type SET DEFAULT 'med_product_ingredient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_ingredient_amount ALTER COLUMN _type SET DEFAULT 'med_product_ingredient_amount'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_ingredient_amount_denominator ALTER COLUMN _type SET DEFAULT 'med_product_ingredient_amount_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_ingredient_amount_numerator ALTER COLUMN _type SET DEFAULT 'med_product_ingredient_amount_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_product_ingredient_item ALTER COLUMN _type SET DEFAULT 'med_product_ingredient_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs ALTER COLUMN _type SET DEFAULT 'med_prs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dispense ALTER COLUMN _type SET DEFAULT 'med_prs_dispense'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dispense_med ALTER COLUMN _type SET DEFAULT 'med_prs_dispense_med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dispense_quantity ALTER COLUMN _type SET DEFAULT 'med_prs_dispense_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dispense_validity_period ALTER COLUMN _type SET DEFAULT 'med_prs_dispense_validity_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_additional_instructions ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_additional_instructions'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_additional_instructions_cd ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_additional_instructions_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_additional_instructions_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_additional_instructions_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_as_needed_codeable_concept ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_as_needed_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_as_needed_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_as_needed_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_dose_quantity ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_dose_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_max_dose_per_period ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_max_dose_per_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_max_dose_per_period_denominator ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_max_dose_per_period_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_max_dose_per_period_numerator ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_max_dose_per_period_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_method ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_method_cd ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_method_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_rate ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_rate'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_rate_denominator ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_rate_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_rate_numerator ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_rate_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_route ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_route'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_route_cd ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_route_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_route_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_route_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_site ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_site_cd ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_site_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_timing_period ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_timing_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_timing_schedule ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_timing_schedule'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_timing_schedule_event ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_timing_schedule_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_dosage_instruction_timing_schedule_repeat ALTER COLUMN _type SET DEFAULT 'med_prs_dosage_instruction_timing_schedule_repeat'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_encounter ALTER COLUMN _type SET DEFAULT 'med_prs_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_idn ALTER COLUMN _type SET DEFAULT 'med_prs_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_idn_assigner ALTER COLUMN _type SET DEFAULT 'med_prs_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_idn_period ALTER COLUMN _type SET DEFAULT 'med_prs_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_med ALTER COLUMN _type SET DEFAULT 'med_prs_med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_patient ALTER COLUMN _type SET DEFAULT 'med_prs_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_prescriber ALTER COLUMN _type SET DEFAULT 'med_prs_prescriber'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_reason_codeable_concept ALTER COLUMN _type SET DEFAULT 'med_prs_reason_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_reason_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'med_prs_reason_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_reason_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_reason_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_reason_resource_reference ALTER COLUMN _type SET DEFAULT 'med_prs_reason_resource_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution ALTER COLUMN _type SET DEFAULT 'med_prs_substitution'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_reason ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_reason_cd ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_type ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_type_cd ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_substitution_type_cd_vs ALTER COLUMN _type SET DEFAULT 'med_prs_substitution_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_prs_text ALTER COLUMN _type SET DEFAULT 'med_prs_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st ALTER COLUMN _type SET DEFAULT 'med_st'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_device ALTER COLUMN _type SET DEFAULT 'med_st_device'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage ALTER COLUMN _type SET DEFAULT 'med_st_dosage'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_as_needed_codeable_concept ALTER COLUMN _type SET DEFAULT 'med_st_dosage_as_needed_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_as_needed_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'med_st_dosage_as_needed_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_as_needed_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'med_st_dosage_as_needed_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_max_dose_per_period ALTER COLUMN _type SET DEFAULT 'med_st_dosage_max_dose_per_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_max_dose_per_period_denominator ALTER COLUMN _type SET DEFAULT 'med_st_dosage_max_dose_per_period_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_max_dose_per_period_numerator ALTER COLUMN _type SET DEFAULT 'med_st_dosage_max_dose_per_period_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_method ALTER COLUMN _type SET DEFAULT 'med_st_dosage_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_method_cd ALTER COLUMN _type SET DEFAULT 'med_st_dosage_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_method_cd_vs ALTER COLUMN _type SET DEFAULT 'med_st_dosage_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_quantity ALTER COLUMN _type SET DEFAULT 'med_st_dosage_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_rate ALTER COLUMN _type SET DEFAULT 'med_st_dosage_rate'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_rate_denominator ALTER COLUMN _type SET DEFAULT 'med_st_dosage_rate_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_rate_numerator ALTER COLUMN _type SET DEFAULT 'med_st_dosage_rate_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_route ALTER COLUMN _type SET DEFAULT 'med_st_dosage_route'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_route_cd ALTER COLUMN _type SET DEFAULT 'med_st_dosage_route_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_route_cd_vs ALTER COLUMN _type SET DEFAULT 'med_st_dosage_route_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_site ALTER COLUMN _type SET DEFAULT 'med_st_dosage_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_site_cd ALTER COLUMN _type SET DEFAULT 'med_st_dosage_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_site_cd_vs ALTER COLUMN _type SET DEFAULT 'med_st_dosage_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_timing ALTER COLUMN _type SET DEFAULT 'med_st_dosage_timing'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_timing_event ALTER COLUMN _type SET DEFAULT 'med_st_dosage_timing_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_dosage_timing_repeat ALTER COLUMN _type SET DEFAULT 'med_st_dosage_timing_repeat'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_idn ALTER COLUMN _type SET DEFAULT 'med_st_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_idn_assigner ALTER COLUMN _type SET DEFAULT 'med_st_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_idn_period ALTER COLUMN _type SET DEFAULT 'med_st_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_med ALTER COLUMN _type SET DEFAULT 'med_st_med'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_patient ALTER COLUMN _type SET DEFAULT 'med_st_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_reason_not_given ALTER COLUMN _type SET DEFAULT 'med_st_reason_not_given'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_reason_not_given_cd ALTER COLUMN _type SET DEFAULT 'med_st_reason_not_given_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_reason_not_given_cd_vs ALTER COLUMN _type SET DEFAULT 'med_st_reason_not_given_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_text ALTER COLUMN _type SET DEFAULT 'med_st_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_st_when_given ALTER COLUMN _type SET DEFAULT 'med_st_when_given'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY med_text ALTER COLUMN _type SET DEFAULT 'med_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media ALTER COLUMN _type SET DEFAULT 'media'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_content ALTER COLUMN _type SET DEFAULT 'media_content'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_idn ALTER COLUMN _type SET DEFAULT 'media_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_idn_assigner ALTER COLUMN _type SET DEFAULT 'media_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_idn_period ALTER COLUMN _type SET DEFAULT 'media_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_operator ALTER COLUMN _type SET DEFAULT 'media_operator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_subject ALTER COLUMN _type SET DEFAULT 'media_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_subtype ALTER COLUMN _type SET DEFAULT 'media_subtype'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_subtype_cd ALTER COLUMN _type SET DEFAULT 'media_subtype_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_subtype_cd_vs ALTER COLUMN _type SET DEFAULT 'media_subtype_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_text ALTER COLUMN _type SET DEFAULT 'media_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_view ALTER COLUMN _type SET DEFAULT 'media_view'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_view_cd ALTER COLUMN _type SET DEFAULT 'media_view_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY media_view_cd_vs ALTER COLUMN _type SET DEFAULT 'media_view_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header ALTER COLUMN _type SET DEFAULT 'message_header'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_author ALTER COLUMN _type SET DEFAULT 'message_header_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_data ALTER COLUMN _type SET DEFAULT 'message_header_data'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_destination ALTER COLUMN _type SET DEFAULT 'message_header_destination'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_destination_target ALTER COLUMN _type SET DEFAULT 'message_header_destination_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_enterer ALTER COLUMN _type SET DEFAULT 'message_header_enterer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_event ALTER COLUMN _type SET DEFAULT 'message_header_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_event_vs ALTER COLUMN _type SET DEFAULT 'message_header_event_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_reason ALTER COLUMN _type SET DEFAULT 'message_header_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_reason_cd ALTER COLUMN _type SET DEFAULT 'message_header_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'message_header_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_receiver ALTER COLUMN _type SET DEFAULT 'message_header_receiver'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_response ALTER COLUMN _type SET DEFAULT 'message_header_response'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_response_details ALTER COLUMN _type SET DEFAULT 'message_header_response_details'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_responsible ALTER COLUMN _type SET DEFAULT 'message_header_responsible'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_source ALTER COLUMN _type SET DEFAULT 'message_header_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_source_contact ALTER COLUMN _type SET DEFAULT 'message_header_source_contact'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_source_contact_period ALTER COLUMN _type SET DEFAULT 'message_header_source_contact_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY message_header_text ALTER COLUMN _type SET DEFAULT 'message_header_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation ALTER COLUMN _type SET DEFAULT 'observation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_applies_period ALTER COLUMN _type SET DEFAULT 'observation_applies_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_body_site ALTER COLUMN _type SET DEFAULT 'observation_body_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_body_site_cd ALTER COLUMN _type SET DEFAULT 'observation_body_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_body_site_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_body_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_idn ALTER COLUMN _type SET DEFAULT 'observation_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_idn_assigner ALTER COLUMN _type SET DEFAULT 'observation_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_idn_period ALTER COLUMN _type SET DEFAULT 'observation_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_interpretation ALTER COLUMN _type SET DEFAULT 'observation_interpretation'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_interpretation_cd ALTER COLUMN _type SET DEFAULT 'observation_interpretation_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_interpretation_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_interpretation_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_method ALTER COLUMN _type SET DEFAULT 'observation_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_method_cd ALTER COLUMN _type SET DEFAULT 'observation_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_method_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_name ALTER COLUMN _type SET DEFAULT 'observation_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_name_cd ALTER COLUMN _type SET DEFAULT 'observation_name_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_name_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_name_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_performer ALTER COLUMN _type SET DEFAULT 'observation_performer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range ALTER COLUMN _type SET DEFAULT 'observation_reference_range'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_age ALTER COLUMN _type SET DEFAULT 'observation_reference_range_age'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_age_high ALTER COLUMN _type SET DEFAULT 'observation_reference_range_age_high'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_age_low ALTER COLUMN _type SET DEFAULT 'observation_reference_range_age_low'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_high ALTER COLUMN _type SET DEFAULT 'observation_reference_range_high'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_low ALTER COLUMN _type SET DEFAULT 'observation_reference_range_low'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_meaning ALTER COLUMN _type SET DEFAULT 'observation_reference_range_meaning'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_meaning_cd ALTER COLUMN _type SET DEFAULT 'observation_reference_range_meaning_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_reference_range_meaning_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_reference_range_meaning_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_related ALTER COLUMN _type SET DEFAULT 'observation_related'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_related_target ALTER COLUMN _type SET DEFAULT 'observation_related_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_specimen ALTER COLUMN _type SET DEFAULT 'observation_specimen'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_subject ALTER COLUMN _type SET DEFAULT 'observation_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_text ALTER COLUMN _type SET DEFAULT 'observation_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_attachment ALTER COLUMN _type SET DEFAULT 'observation_value_attachment'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_codeable_concept ALTER COLUMN _type SET DEFAULT 'observation_value_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'observation_value_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'observation_value_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_period ALTER COLUMN _type SET DEFAULT 'observation_value_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_quantity ALTER COLUMN _type SET DEFAULT 'observation_value_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_ratio ALTER COLUMN _type SET DEFAULT 'observation_value_ratio'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_ratio_denominator ALTER COLUMN _type SET DEFAULT 'observation_value_ratio_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_ratio_numerator ALTER COLUMN _type SET DEFAULT 'observation_value_ratio_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_sampled_data ALTER COLUMN _type SET DEFAULT 'observation_value_sampled_data'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY observation_value_sampled_data_origin ALTER COLUMN _type SET DEFAULT 'observation_value_sampled_data_origin'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY operation_outcome ALTER COLUMN _type SET DEFAULT 'operation_outcome'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY operation_outcome_issue ALTER COLUMN _type SET DEFAULT 'operation_outcome_issue'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY operation_outcome_issue_type ALTER COLUMN _type SET DEFAULT 'operation_outcome_issue_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY operation_outcome_issue_type_vs ALTER COLUMN _type SET DEFAULT 'operation_outcome_issue_type_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY operation_outcome_text ALTER COLUMN _type SET DEFAULT 'operation_outcome_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY "order" ALTER COLUMN _type SET DEFAULT 'order'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_authority ALTER COLUMN _type SET DEFAULT 'order_authority'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_detail ALTER COLUMN _type SET DEFAULT 'order_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_idn ALTER COLUMN _type SET DEFAULT 'order_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_idn_assigner ALTER COLUMN _type SET DEFAULT 'order_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_idn_period ALTER COLUMN _type SET DEFAULT 'order_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_reason_codeable_concept ALTER COLUMN _type SET DEFAULT 'order_reason_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_reason_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'order_reason_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_reason_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'order_reason_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_reason_resource_reference ALTER COLUMN _type SET DEFAULT 'order_reason_resource_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response ALTER COLUMN _type SET DEFAULT 'order_response'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_authority_codeable_concept ALTER COLUMN _type SET DEFAULT 'order_response_authority_codeable_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_authority_codeable_concept_cd ALTER COLUMN _type SET DEFAULT 'order_response_authority_codeable_concept_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_authority_codeable_concept_cd_vs ALTER COLUMN _type SET DEFAULT 'order_response_authority_codeable_concept_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_authority_resource_reference ALTER COLUMN _type SET DEFAULT 'order_response_authority_resource_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_fulfillment ALTER COLUMN _type SET DEFAULT 'order_response_fulfillment'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_idn ALTER COLUMN _type SET DEFAULT 'order_response_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_idn_assigner ALTER COLUMN _type SET DEFAULT 'order_response_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_idn_period ALTER COLUMN _type SET DEFAULT 'order_response_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_request ALTER COLUMN _type SET DEFAULT 'order_response_request'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_text ALTER COLUMN _type SET DEFAULT 'order_response_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_response_who ALTER COLUMN _type SET DEFAULT 'order_response_who'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_source ALTER COLUMN _type SET DEFAULT 'order_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_subject ALTER COLUMN _type SET DEFAULT 'order_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_target ALTER COLUMN _type SET DEFAULT 'order_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_text ALTER COLUMN _type SET DEFAULT 'order_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when ALTER COLUMN _type SET DEFAULT 'order_when'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_code ALTER COLUMN _type SET DEFAULT 'order_when_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_code_cd ALTER COLUMN _type SET DEFAULT 'order_when_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_code_cd_vs ALTER COLUMN _type SET DEFAULT 'order_when_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_schedule ALTER COLUMN _type SET DEFAULT 'order_when_schedule'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_schedule_event ALTER COLUMN _type SET DEFAULT 'order_when_schedule_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY order_when_schedule_repeat ALTER COLUMN _type SET DEFAULT 'order_when_schedule_repeat'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization ALTER COLUMN _type SET DEFAULT 'organization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_address ALTER COLUMN _type SET DEFAULT 'organization_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_address_period ALTER COLUMN _type SET DEFAULT 'organization_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact ALTER COLUMN _type SET DEFAULT 'organization_contact'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_address ALTER COLUMN _type SET DEFAULT 'organization_contact_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_address_period ALTER COLUMN _type SET DEFAULT 'organization_contact_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_gender ALTER COLUMN _type SET DEFAULT 'organization_contact_gender'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_gender_cd ALTER COLUMN _type SET DEFAULT 'organization_contact_gender_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_gender_cd_vs ALTER COLUMN _type SET DEFAULT 'organization_contact_gender_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_name ALTER COLUMN _type SET DEFAULT 'organization_contact_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_name_period ALTER COLUMN _type SET DEFAULT 'organization_contact_name_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_purpose ALTER COLUMN _type SET DEFAULT 'organization_contact_purpose'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_purpose_cd ALTER COLUMN _type SET DEFAULT 'organization_contact_purpose_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_purpose_cd_vs ALTER COLUMN _type SET DEFAULT 'organization_contact_purpose_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_telecom ALTER COLUMN _type SET DEFAULT 'organization_contact_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_contact_telecom_period ALTER COLUMN _type SET DEFAULT 'organization_contact_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_idn ALTER COLUMN _type SET DEFAULT 'organization_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_idn_assigner ALTER COLUMN _type SET DEFAULT 'organization_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_idn_period ALTER COLUMN _type SET DEFAULT 'organization_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_loc ALTER COLUMN _type SET DEFAULT 'organization_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_part_of ALTER COLUMN _type SET DEFAULT 'organization_part_of'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_telecom ALTER COLUMN _type SET DEFAULT 'organization_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_telecom_period ALTER COLUMN _type SET DEFAULT 'organization_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_text ALTER COLUMN _type SET DEFAULT 'organization_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_type ALTER COLUMN _type SET DEFAULT 'organization_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_type_cd ALTER COLUMN _type SET DEFAULT 'organization_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY organization_type_cd_vs ALTER COLUMN _type SET DEFAULT 'organization_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other ALTER COLUMN _type SET DEFAULT 'other'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_author ALTER COLUMN _type SET DEFAULT 'other_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_code ALTER COLUMN _type SET DEFAULT 'other_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_code_cd ALTER COLUMN _type SET DEFAULT 'other_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_code_cd_vs ALTER COLUMN _type SET DEFAULT 'other_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_idn ALTER COLUMN _type SET DEFAULT 'other_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_idn_assigner ALTER COLUMN _type SET DEFAULT 'other_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_idn_period ALTER COLUMN _type SET DEFAULT 'other_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_subject ALTER COLUMN _type SET DEFAULT 'other_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY other_text ALTER COLUMN _type SET DEFAULT 'other_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient ALTER COLUMN _type SET DEFAULT 'patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_address ALTER COLUMN _type SET DEFAULT 'patient_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_address_period ALTER COLUMN _type SET DEFAULT 'patient_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal ALTER COLUMN _type SET DEFAULT 'patient_animal'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_breed ALTER COLUMN _type SET DEFAULT 'patient_animal_breed'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_breed_cd ALTER COLUMN _type SET DEFAULT 'patient_animal_breed_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_breed_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_animal_breed_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_gender_status ALTER COLUMN _type SET DEFAULT 'patient_animal_gender_status'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_gender_status_cd ALTER COLUMN _type SET DEFAULT 'patient_animal_gender_status_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_gender_status_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_animal_gender_status_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_species ALTER COLUMN _type SET DEFAULT 'patient_animal_species'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_species_cd ALTER COLUMN _type SET DEFAULT 'patient_animal_species_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_animal_species_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_animal_species_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_care_provider ALTER COLUMN _type SET DEFAULT 'patient_care_provider'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_communication ALTER COLUMN _type SET DEFAULT 'patient_communication'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_communication_cd ALTER COLUMN _type SET DEFAULT 'patient_communication_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_communication_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_communication_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact ALTER COLUMN _type SET DEFAULT 'patient_contact'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_address ALTER COLUMN _type SET DEFAULT 'patient_contact_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_address_period ALTER COLUMN _type SET DEFAULT 'patient_contact_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_gender ALTER COLUMN _type SET DEFAULT 'patient_contact_gender'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_gender_cd ALTER COLUMN _type SET DEFAULT 'patient_contact_gender_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_gender_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_contact_gender_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_name ALTER COLUMN _type SET DEFAULT 'patient_contact_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_name_period ALTER COLUMN _type SET DEFAULT 'patient_contact_name_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_organization ALTER COLUMN _type SET DEFAULT 'patient_contact_organization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_relationship ALTER COLUMN _type SET DEFAULT 'patient_contact_relationship'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_relationship_cd ALTER COLUMN _type SET DEFAULT 'patient_contact_relationship_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_relationship_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_contact_relationship_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_telecom ALTER COLUMN _type SET DEFAULT 'patient_contact_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_contact_telecom_period ALTER COLUMN _type SET DEFAULT 'patient_contact_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_gender ALTER COLUMN _type SET DEFAULT 'patient_gender'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_gender_cd ALTER COLUMN _type SET DEFAULT 'patient_gender_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_gender_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_gender_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_idn ALTER COLUMN _type SET DEFAULT 'patient_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_idn_assigner ALTER COLUMN _type SET DEFAULT 'patient_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_idn_period ALTER COLUMN _type SET DEFAULT 'patient_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_link ALTER COLUMN _type SET DEFAULT 'patient_link'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_link_other ALTER COLUMN _type SET DEFAULT 'patient_link_other'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_managing_organization ALTER COLUMN _type SET DEFAULT 'patient_managing_organization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_marital_status ALTER COLUMN _type SET DEFAULT 'patient_marital_status'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_marital_status_cd ALTER COLUMN _type SET DEFAULT 'patient_marital_status_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_marital_status_cd_vs ALTER COLUMN _type SET DEFAULT 'patient_marital_status_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_name ALTER COLUMN _type SET DEFAULT 'patient_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_name_period ALTER COLUMN _type SET DEFAULT 'patient_name_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_photo ALTER COLUMN _type SET DEFAULT 'patient_photo'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_telecom ALTER COLUMN _type SET DEFAULT 'patient_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_telecom_period ALTER COLUMN _type SET DEFAULT 'patient_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY patient_text ALTER COLUMN _type SET DEFAULT 'patient_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner ALTER COLUMN _type SET DEFAULT 'practitioner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_address ALTER COLUMN _type SET DEFAULT 'practitioner_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_address_period ALTER COLUMN _type SET DEFAULT 'practitioner_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_communication ALTER COLUMN _type SET DEFAULT 'practitioner_communication'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_communication_cd ALTER COLUMN _type SET DEFAULT 'practitioner_communication_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_communication_cd_vs ALTER COLUMN _type SET DEFAULT 'practitioner_communication_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_gender ALTER COLUMN _type SET DEFAULT 'practitioner_gender'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_gender_cd ALTER COLUMN _type SET DEFAULT 'practitioner_gender_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_gender_cd_vs ALTER COLUMN _type SET DEFAULT 'practitioner_gender_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_idn ALTER COLUMN _type SET DEFAULT 'practitioner_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_idn_assigner ALTER COLUMN _type SET DEFAULT 'practitioner_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_idn_period ALTER COLUMN _type SET DEFAULT 'practitioner_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_loc ALTER COLUMN _type SET DEFAULT 'practitioner_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_name ALTER COLUMN _type SET DEFAULT 'practitioner_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_name_period ALTER COLUMN _type SET DEFAULT 'practitioner_name_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_organization ALTER COLUMN _type SET DEFAULT 'practitioner_organization'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_period ALTER COLUMN _type SET DEFAULT 'practitioner_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_photo ALTER COLUMN _type SET DEFAULT 'practitioner_photo'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification ALTER COLUMN _type SET DEFAULT 'practitioner_qualification'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification_code ALTER COLUMN _type SET DEFAULT 'practitioner_qualification_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification_code_cd ALTER COLUMN _type SET DEFAULT 'practitioner_qualification_code_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification_code_cd_vs ALTER COLUMN _type SET DEFAULT 'practitioner_qualification_code_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification_issuer ALTER COLUMN _type SET DEFAULT 'practitioner_qualification_issuer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_qualification_period ALTER COLUMN _type SET DEFAULT 'practitioner_qualification_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_role ALTER COLUMN _type SET DEFAULT 'practitioner_role'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_role_cd ALTER COLUMN _type SET DEFAULT 'practitioner_role_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_role_cd_vs ALTER COLUMN _type SET DEFAULT 'practitioner_role_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_specialty ALTER COLUMN _type SET DEFAULT 'practitioner_specialty'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_specialty_cd ALTER COLUMN _type SET DEFAULT 'practitioner_specialty_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_specialty_cd_vs ALTER COLUMN _type SET DEFAULT 'practitioner_specialty_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_telecom ALTER COLUMN _type SET DEFAULT 'practitioner_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_telecom_period ALTER COLUMN _type SET DEFAULT 'practitioner_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY practitioner_text ALTER COLUMN _type SET DEFAULT 'practitioner_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure ALTER COLUMN _type SET DEFAULT 'procedure'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_body_site ALTER COLUMN _type SET DEFAULT 'procedure_body_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_body_site_cd ALTER COLUMN _type SET DEFAULT 'procedure_body_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_body_site_cd_vs ALTER COLUMN _type SET DEFAULT 'procedure_body_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_complication ALTER COLUMN _type SET DEFAULT 'procedure_complication'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_complication_cd ALTER COLUMN _type SET DEFAULT 'procedure_complication_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_complication_cd_vs ALTER COLUMN _type SET DEFAULT 'procedure_complication_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_date ALTER COLUMN _type SET DEFAULT 'procedure_date'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_encounter ALTER COLUMN _type SET DEFAULT 'procedure_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_idn ALTER COLUMN _type SET DEFAULT 'procedure_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_idn_assigner ALTER COLUMN _type SET DEFAULT 'procedure_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_idn_period ALTER COLUMN _type SET DEFAULT 'procedure_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_indication ALTER COLUMN _type SET DEFAULT 'procedure_indication'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_indication_cd ALTER COLUMN _type SET DEFAULT 'procedure_indication_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_indication_cd_vs ALTER COLUMN _type SET DEFAULT 'procedure_indication_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_performer ALTER COLUMN _type SET DEFAULT 'procedure_performer'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_performer_person ALTER COLUMN _type SET DEFAULT 'procedure_performer_person'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_performer_role ALTER COLUMN _type SET DEFAULT 'procedure_performer_role'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_performer_role_cd ALTER COLUMN _type SET DEFAULT 'procedure_performer_role_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_performer_role_cd_vs ALTER COLUMN _type SET DEFAULT 'procedure_performer_role_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_related_item ALTER COLUMN _type SET DEFAULT 'procedure_related_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_related_item_target ALTER COLUMN _type SET DEFAULT 'procedure_related_item_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_report ALTER COLUMN _type SET DEFAULT 'procedure_report'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_subject ALTER COLUMN _type SET DEFAULT 'procedure_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_text ALTER COLUMN _type SET DEFAULT 'procedure_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_type ALTER COLUMN _type SET DEFAULT 'procedure_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_type_cd ALTER COLUMN _type SET DEFAULT 'procedure_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY procedure_type_cd_vs ALTER COLUMN _type SET DEFAULT 'procedure_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile ALTER COLUMN _type SET DEFAULT 'profile'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_code ALTER COLUMN _type SET DEFAULT 'profile_code'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_code_vs ALTER COLUMN _type SET DEFAULT 'profile_code_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_extension_defn ALTER COLUMN _type SET DEFAULT 'profile_extension_defn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_mapping ALTER COLUMN _type SET DEFAULT 'profile_mapping'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_query ALTER COLUMN _type SET DEFAULT 'profile_query'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure ALTER COLUMN _type SET DEFAULT 'profile_structure'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element ALTER COLUMN _type SET DEFAULT 'profile_structure_element'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition_binding ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition_binding'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition_binding_reference_resource ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition_binding_reference_resource_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition_constraint ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition_constraint'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition_mapping ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition_mapping'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_definition_type ALTER COLUMN _type SET DEFAULT 'profile_structure_element_definition_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_element_slicing ALTER COLUMN _type SET DEFAULT 'profile_structure_element_slicing'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_structure_search_param ALTER COLUMN _type SET DEFAULT 'profile_structure_search_param'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_telecom ALTER COLUMN _type SET DEFAULT 'profile_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_telecom_period ALTER COLUMN _type SET DEFAULT 'profile_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY profile_text ALTER COLUMN _type SET DEFAULT 'profile_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance ALTER COLUMN _type SET DEFAULT 'provenance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_agent ALTER COLUMN _type SET DEFAULT 'provenance_agent'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_agent_role ALTER COLUMN _type SET DEFAULT 'provenance_agent_role'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_agent_role_vs ALTER COLUMN _type SET DEFAULT 'provenance_agent_role_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_agent_type ALTER COLUMN _type SET DEFAULT 'provenance_agent_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_agent_type_vs ALTER COLUMN _type SET DEFAULT 'provenance_agent_type_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_entity ALTER COLUMN _type SET DEFAULT 'provenance_entity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_entity_type ALTER COLUMN _type SET DEFAULT 'provenance_entity_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_entity_type_vs ALTER COLUMN _type SET DEFAULT 'provenance_entity_type_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_loc ALTER COLUMN _type SET DEFAULT 'provenance_loc'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_period ALTER COLUMN _type SET DEFAULT 'provenance_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_reason ALTER COLUMN _type SET DEFAULT 'provenance_reason'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_reason_cd ALTER COLUMN _type SET DEFAULT 'provenance_reason_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_reason_cd_vs ALTER COLUMN _type SET DEFAULT 'provenance_reason_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_target ALTER COLUMN _type SET DEFAULT 'provenance_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY provenance_text ALTER COLUMN _type SET DEFAULT 'provenance_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY query ALTER COLUMN _type SET DEFAULT 'query'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY query_response ALTER COLUMN _type SET DEFAULT 'query_response'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY query_response_reference ALTER COLUMN _type SET DEFAULT 'query_response_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY query_text ALTER COLUMN _type SET DEFAULT 'query_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire ALTER COLUMN _type SET DEFAULT 'questionnaire'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_author ALTER COLUMN _type SET DEFAULT 'questionnaire_author'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_encounter ALTER COLUMN _type SET DEFAULT 'questionnaire_encounter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group ALTER COLUMN _type SET DEFAULT 'questionnaire_group'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_name ALTER COLUMN _type SET DEFAULT 'questionnaire_group_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_name_cd ALTER COLUMN _type SET DEFAULT 'questionnaire_group_name_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_name_cd_vs ALTER COLUMN _type SET DEFAULT 'questionnaire_group_name_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_choice ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_choice'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_choice_vs ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_choice_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_name ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_name_cd ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_name_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_name_cd_vs ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_name_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_question_options ALTER COLUMN _type SET DEFAULT 'questionnaire_group_question_options'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_group_subject ALTER COLUMN _type SET DEFAULT 'questionnaire_group_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_idn ALTER COLUMN _type SET DEFAULT 'questionnaire_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_idn_assigner ALTER COLUMN _type SET DEFAULT 'questionnaire_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_idn_period ALTER COLUMN _type SET DEFAULT 'questionnaire_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_name ALTER COLUMN _type SET DEFAULT 'questionnaire_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_name_cd ALTER COLUMN _type SET DEFAULT 'questionnaire_name_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_name_cd_vs ALTER COLUMN _type SET DEFAULT 'questionnaire_name_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_source ALTER COLUMN _type SET DEFAULT 'questionnaire_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_subject ALTER COLUMN _type SET DEFAULT 'questionnaire_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY questionnaire_text ALTER COLUMN _type SET DEFAULT 'questionnaire_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person ALTER COLUMN _type SET DEFAULT 'related_person'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_address ALTER COLUMN _type SET DEFAULT 'related_person_address'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_address_period ALTER COLUMN _type SET DEFAULT 'related_person_address_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_gender ALTER COLUMN _type SET DEFAULT 'related_person_gender'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_gender_cd ALTER COLUMN _type SET DEFAULT 'related_person_gender_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_gender_cd_vs ALTER COLUMN _type SET DEFAULT 'related_person_gender_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_idn ALTER COLUMN _type SET DEFAULT 'related_person_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_idn_assigner ALTER COLUMN _type SET DEFAULT 'related_person_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_idn_period ALTER COLUMN _type SET DEFAULT 'related_person_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_name ALTER COLUMN _type SET DEFAULT 'related_person_name'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_name_period ALTER COLUMN _type SET DEFAULT 'related_person_name_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_patient ALTER COLUMN _type SET DEFAULT 'related_person_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_photo ALTER COLUMN _type SET DEFAULT 'related_person_photo'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_relationship ALTER COLUMN _type SET DEFAULT 'related_person_relationship'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_relationship_cd ALTER COLUMN _type SET DEFAULT 'related_person_relationship_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_relationship_cd_vs ALTER COLUMN _type SET DEFAULT 'related_person_relationship_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_telecom ALTER COLUMN _type SET DEFAULT 'related_person_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_telecom_period ALTER COLUMN _type SET DEFAULT 'related_person_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY related_person_text ALTER COLUMN _type SET DEFAULT 'related_person_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event ALTER COLUMN _type SET DEFAULT 'security_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event ALTER COLUMN _type SET DEFAULT 'security_event_event'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_subtype ALTER COLUMN _type SET DEFAULT 'security_event_event_subtype'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_subtype_cd ALTER COLUMN _type SET DEFAULT 'security_event_event_subtype_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_subtype_cd_vs ALTER COLUMN _type SET DEFAULT 'security_event_event_subtype_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_type ALTER COLUMN _type SET DEFAULT 'security_event_event_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_type_cd ALTER COLUMN _type SET DEFAULT 'security_event_event_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_event_type_cd_vs ALTER COLUMN _type SET DEFAULT 'security_event_event_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object ALTER COLUMN _type SET DEFAULT 'security_event_object'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_detail ALTER COLUMN _type SET DEFAULT 'security_event_object_detail'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_idn ALTER COLUMN _type SET DEFAULT 'security_event_object_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_idn_assigner ALTER COLUMN _type SET DEFAULT 'security_event_object_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_idn_period ALTER COLUMN _type SET DEFAULT 'security_event_object_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_reference ALTER COLUMN _type SET DEFAULT 'security_event_object_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_sensitivity ALTER COLUMN _type SET DEFAULT 'security_event_object_sensitivity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_sensitivity_cd ALTER COLUMN _type SET DEFAULT 'security_event_object_sensitivity_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_object_sensitivity_cd_vs ALTER COLUMN _type SET DEFAULT 'security_event_object_sensitivity_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant ALTER COLUMN _type SET DEFAULT 'security_event_participant'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_media ALTER COLUMN _type SET DEFAULT 'security_event_participant_media'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_media_vs ALTER COLUMN _type SET DEFAULT 'security_event_participant_media_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_network ALTER COLUMN _type SET DEFAULT 'security_event_participant_network'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_reference ALTER COLUMN _type SET DEFAULT 'security_event_participant_reference'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_role ALTER COLUMN _type SET DEFAULT 'security_event_participant_role'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_role_cd ALTER COLUMN _type SET DEFAULT 'security_event_participant_role_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_participant_role_cd_vs ALTER COLUMN _type SET DEFAULT 'security_event_participant_role_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_source ALTER COLUMN _type SET DEFAULT 'security_event_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_source_type ALTER COLUMN _type SET DEFAULT 'security_event_source_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_source_type_vs ALTER COLUMN _type SET DEFAULT 'security_event_source_type_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY security_event_text ALTER COLUMN _type SET DEFAULT 'security_event_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen ALTER COLUMN _type SET DEFAULT 'specimen'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_accession_identifier ALTER COLUMN _type SET DEFAULT 'specimen_accession_identifier'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_accession_identifier_assigner ALTER COLUMN _type SET DEFAULT 'specimen_accession_identifier_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_accession_identifier_period ALTER COLUMN _type SET DEFAULT 'specimen_accession_identifier_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection ALTER COLUMN _type SET DEFAULT 'specimen_collection'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_collected_period ALTER COLUMN _type SET DEFAULT 'specimen_collection_collected_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_collector ALTER COLUMN _type SET DEFAULT 'specimen_collection_collector'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_method ALTER COLUMN _type SET DEFAULT 'specimen_collection_method'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_method_cd ALTER COLUMN _type SET DEFAULT 'specimen_collection_method_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_method_cd_vs ALTER COLUMN _type SET DEFAULT 'specimen_collection_method_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_quantity ALTER COLUMN _type SET DEFAULT 'specimen_collection_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_source_site ALTER COLUMN _type SET DEFAULT 'specimen_collection_source_site'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_source_site_cd ALTER COLUMN _type SET DEFAULT 'specimen_collection_source_site_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_collection_source_site_cd_vs ALTER COLUMN _type SET DEFAULT 'specimen_collection_source_site_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container ALTER COLUMN _type SET DEFAULT 'specimen_container'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_additive ALTER COLUMN _type SET DEFAULT 'specimen_container_additive'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_capacity ALTER COLUMN _type SET DEFAULT 'specimen_container_capacity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_idn ALTER COLUMN _type SET DEFAULT 'specimen_container_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_idn_assigner ALTER COLUMN _type SET DEFAULT 'specimen_container_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_idn_period ALTER COLUMN _type SET DEFAULT 'specimen_container_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_specimen_quantity ALTER COLUMN _type SET DEFAULT 'specimen_container_specimen_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_type ALTER COLUMN _type SET DEFAULT 'specimen_container_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_type_cd ALTER COLUMN _type SET DEFAULT 'specimen_container_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_container_type_cd_vs ALTER COLUMN _type SET DEFAULT 'specimen_container_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_idn ALTER COLUMN _type SET DEFAULT 'specimen_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_idn_assigner ALTER COLUMN _type SET DEFAULT 'specimen_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_idn_period ALTER COLUMN _type SET DEFAULT 'specimen_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_source ALTER COLUMN _type SET DEFAULT 'specimen_source'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_source_target ALTER COLUMN _type SET DEFAULT 'specimen_source_target'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_subject ALTER COLUMN _type SET DEFAULT 'specimen_subject'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_text ALTER COLUMN _type SET DEFAULT 'specimen_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_treatment ALTER COLUMN _type SET DEFAULT 'specimen_treatment'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_treatment_additive ALTER COLUMN _type SET DEFAULT 'specimen_treatment_additive'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_treatment_procedure ALTER COLUMN _type SET DEFAULT 'specimen_treatment_procedure'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_treatment_procedure_cd ALTER COLUMN _type SET DEFAULT 'specimen_treatment_procedure_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_treatment_procedure_cd_vs ALTER COLUMN _type SET DEFAULT 'specimen_treatment_procedure_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_type ALTER COLUMN _type SET DEFAULT 'specimen_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_type_cd ALTER COLUMN _type SET DEFAULT 'specimen_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY specimen_type_cd_vs ALTER COLUMN _type SET DEFAULT 'specimen_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance ALTER COLUMN _type SET DEFAULT 'substance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_ingredient ALTER COLUMN _type SET DEFAULT 'substance_ingredient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_ingredient_quantity ALTER COLUMN _type SET DEFAULT 'substance_ingredient_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_ingredient_quantity_denominator ALTER COLUMN _type SET DEFAULT 'substance_ingredient_quantity_denominator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_ingredient_quantity_numerator ALTER COLUMN _type SET DEFAULT 'substance_ingredient_quantity_numerator'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_ingredient_substance ALTER COLUMN _type SET DEFAULT 'substance_ingredient_substance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_instance ALTER COLUMN _type SET DEFAULT 'substance_instance'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_instance_idn ALTER COLUMN _type SET DEFAULT 'substance_instance_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_instance_idn_assigner ALTER COLUMN _type SET DEFAULT 'substance_instance_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_instance_idn_period ALTER COLUMN _type SET DEFAULT 'substance_instance_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_instance_quantity ALTER COLUMN _type SET DEFAULT 'substance_instance_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_text ALTER COLUMN _type SET DEFAULT 'substance_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_type ALTER COLUMN _type SET DEFAULT 'substance_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_type_cd ALTER COLUMN _type SET DEFAULT 'substance_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY substance_type_cd_vs ALTER COLUMN _type SET DEFAULT 'substance_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply ALTER COLUMN _type SET DEFAULT 'supply'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense ALTER COLUMN _type SET DEFAULT 'supply_dispense'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_destination ALTER COLUMN _type SET DEFAULT 'supply_dispense_destination'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_idn ALTER COLUMN _type SET DEFAULT 'supply_dispense_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_idn_assigner ALTER COLUMN _type SET DEFAULT 'supply_dispense_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_idn_period ALTER COLUMN _type SET DEFAULT 'supply_dispense_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_quantity ALTER COLUMN _type SET DEFAULT 'supply_dispense_quantity'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_receiver ALTER COLUMN _type SET DEFAULT 'supply_dispense_receiver'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_supplied_item ALTER COLUMN _type SET DEFAULT 'supply_dispense_supplied_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_supplier ALTER COLUMN _type SET DEFAULT 'supply_dispense_supplier'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_type ALTER COLUMN _type SET DEFAULT 'supply_dispense_type'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_type_cd ALTER COLUMN _type SET DEFAULT 'supply_dispense_type_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_type_cd_vs ALTER COLUMN _type SET DEFAULT 'supply_dispense_type_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_when_handed_over ALTER COLUMN _type SET DEFAULT 'supply_dispense_when_handed_over'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_dispense_when_prepared ALTER COLUMN _type SET DEFAULT 'supply_dispense_when_prepared'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_idn ALTER COLUMN _type SET DEFAULT 'supply_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_idn_assigner ALTER COLUMN _type SET DEFAULT 'supply_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_idn_period ALTER COLUMN _type SET DEFAULT 'supply_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_kind ALTER COLUMN _type SET DEFAULT 'supply_kind'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_kind_cd ALTER COLUMN _type SET DEFAULT 'supply_kind_cd'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_kind_cd_vs ALTER COLUMN _type SET DEFAULT 'supply_kind_cd_vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_ordered_item ALTER COLUMN _type SET DEFAULT 'supply_ordered_item'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_patient ALTER COLUMN _type SET DEFAULT 'supply_patient'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY supply_text ALTER COLUMN _type SET DEFAULT 'supply_text'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs ALTER COLUMN _type SET DEFAULT 'vs'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_compose ALTER COLUMN _type SET DEFAULT 'vs_compose'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_compose_include ALTER COLUMN _type SET DEFAULT 'vs_compose_include'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_compose_include_filter ALTER COLUMN _type SET DEFAULT 'vs_compose_include_filter'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_define ALTER COLUMN _type SET DEFAULT 'vs_define'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_define_concept ALTER COLUMN _type SET DEFAULT 'vs_define_concept'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_expansion ALTER COLUMN _type SET DEFAULT 'vs_expansion'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_expansion_contains ALTER COLUMN _type SET DEFAULT 'vs_expansion_contains'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_expansion_idn ALTER COLUMN _type SET DEFAULT 'vs_expansion_idn'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_expansion_idn_assigner ALTER COLUMN _type SET DEFAULT 'vs_expansion_idn_assigner'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_expansion_idn_period ALTER COLUMN _type SET DEFAULT 'vs_expansion_idn_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_telecom ALTER COLUMN _type SET DEFAULT 'vs_telecom'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_telecom_period ALTER COLUMN _type SET DEFAULT 'vs_telecom_period'::character varying;


--
-- Name: _type; Type: DEFAULT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY vs_text ALTER COLUMN _type SET DEFAULT 'vs_text'::character varying;


--
-- Data for Name: address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: adverse_reaction; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction (id, _type, _unknown_attributes, resource_type, language, container_id, did_not_occur_flag, date) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_exposure; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_exposure (id, _type, _unknown_attributes, parent_id, resource_id, container_id, causality_expectation, type, date) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_exposure_substance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_exposure_substance (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: adverse_reaction_recorder; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_recorder (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_symptom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_symptom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, severity) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_symptom_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_symptom_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_symptom_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_symptom_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: adverse_reaction_symptom_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_symptom_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: adverse_reaction_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY adverse_reaction_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: alert; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert (id, _type, _unknown_attributes, resource_type, language, container_id, status, note) FROM stdin;
\.


--
-- Data for Name: alert_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: alert_category; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_category (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: alert_category_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_category_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: alert_category_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_category_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: alert_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: alert_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: alert_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: alert_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: alert_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY alert_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance (id, _type, _unknown_attributes, resource_type, language, container_id, status, sensitivity_type, criticality, recorded_date) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_reaction; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_reaction (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_recorder; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_recorder (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_sensitivity_test; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_sensitivity_test (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_substance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_substance (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: allergy_intolerance_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY allergy_intolerance_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: attachment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY attachment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: care_plan; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan (id, _type, _unknown_attributes, resource_type, language, container_id, status, modified, notes) FROM stdin;
\.


--
-- Data for Name: care_plan_activity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, prohibited, status, notes) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_action_resulting; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_action_resulting (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple (id, _type, _unknown_attributes, parent_id, resource_id, container_id, category, timing_string, details) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_daily_amount; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_daily_amount (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_performer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_performer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_product; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_product (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_timing_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_timing_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_timing_schedule; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_timing_schedule (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_timing_schedule_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_timing_schedule_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: care_plan_activity_simple_timing_schedule_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_activity_simple_timing_schedule_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: care_plan_concern; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_concern (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_goal; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_goal (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, notes, description) FROM stdin;
\.


--
-- Data for Name: care_plan_goal_concern; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_goal_concern (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: care_plan_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: care_plan_participant; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_participant (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: care_plan_participant_member; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_participant_member (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_participant_role; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_participant_role (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: care_plan_participant_role_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_participant_role_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: care_plan_participant_role_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_participant_role_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: care_plan_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: care_plan_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY care_plan_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: cc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY cc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: cc_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY cc_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: cc_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY cc_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition (id, _type, _unknown_attributes, resource_type, language, container_id, status, date, title) FROM stdin;
\.


--
-- Data for Name: composition_attester; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_attester (id, _type, _unknown_attributes, parent_id, resource_id, container_id, mode, "time") FROM stdin;
\.


--
-- Data for Name: composition_attester_party; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_attester_party (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_class; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_class (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: composition_class_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_class_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: composition_class_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_class_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_confidentiality; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_confidentiality (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: composition_confidentiality_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_confidentiality_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_custodian; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_custodian (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: composition_event_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: composition_event_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: composition_event_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_event_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_event_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_event_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: composition_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: composition_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: composition_section; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section (id, _type, _unknown_attributes, parent_id, resource_id, container_id, title) FROM stdin;
\.


--
-- Data for Name: composition_section_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: composition_section_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: composition_section_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_section_content; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section_content (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_section_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_section_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: composition_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: composition_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: composition_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: composition_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY composition_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: concept_map; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map (id, _type, _unknown_attributes, resource_type, language, container_id, experimental, status, date, copyright, description, publisher, name, version, identifier) FROM stdin;
\.


--
-- Data for Name: concept_map_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, system) FROM stdin;
\.


--
-- Data for Name: concept_map_concept_depends_on; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_concept_depends_on (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, concept, system) FROM stdin;
\.


--
-- Data for Name: concept_map_concept_map; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_concept_map (id, _type, _unknown_attributes, parent_id, resource_id, container_id, equivalence, code, comments, system) FROM stdin;
\.


--
-- Data for Name: concept_map_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: concept_map_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: concept_map_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: concept_map_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: concept_map_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY concept_map_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: condition; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition (id, _type, _unknown_attributes, resource_type, language, container_id, abatement_boolean, status, abatement_date, onset_date, date_asserted, notes) FROM stdin;
\.


--
-- Data for Name: condition_asserter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_asserter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_category; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_category (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_category_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_category_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_category_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_category_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_certainty; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_certainty (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_certainty_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_certainty_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_certainty_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_certainty_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_evidence; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_evidence (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: condition_evidence_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_evidence_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_evidence_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_evidence_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_evidence_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_evidence_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_evidence_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_evidence_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: condition_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: condition_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, detail) FROM stdin;
\.


--
-- Data for Name: condition_loc_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_loc_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_loc_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_loc_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_loc_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_loc_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_related_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_related_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type) FROM stdin;
\.


--
-- Data for Name: condition_related_item_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_related_item_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_related_item_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_related_item_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_related_item_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_related_item_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_related_item_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_related_item_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_severity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_severity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_severity_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_severity_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_severity_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_severity_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_stage; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_stage (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: condition_stage_assessment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_stage_assessment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_stage_summary; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_stage_summary (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: condition_stage_summary_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_stage_summary_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: condition_stage_summary_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_stage_summary_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: condition_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY condition_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: conformance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance (id, _type, _unknown_attributes, resource_type, language, container_id, experimental, accept_unknown, status, format, date, fhir_version, description, publisher, name, version, identifier) FROM stdin;
\.


--
-- Data for Name: conformance_document; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_document (id, _type, _unknown_attributes, parent_id, resource_id, container_id, mode, documentation) FROM stdin;
\.


--
-- Data for Name: conformance_document_profile; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_document_profile (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_implementation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_implementation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, description, url) FROM stdin;
\.


--
-- Data for Name: conformance_messaging; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reliable_cache, documentation, endpoint) FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, focus, mode, category, documentation) FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_code_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_code_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_protocol; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_protocol (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_protocol_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_protocol_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_request; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_request (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_messaging_event_response; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_messaging_event_response (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_profile; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_profile (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_rest; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest (id, _type, _unknown_attributes, parent_id, resource_id, container_id, mode, documentation, document_mailbox) FROM stdin;
\.


--
-- Data for Name: conformance_rest_operation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_operation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, documentation) FROM stdin;
\.


--
-- Data for Name: conformance_rest_query; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_query (id, _type, _unknown_attributes, parent_id, resource_id, container_id, documentation, name, definition) FROM stdin;
\.


--
-- Data for Name: conformance_rest_resource; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_resource (id, _type, _unknown_attributes, parent_id, resource_id, container_id, update_create, read_history, type, search_include) FROM stdin;
\.


--
-- Data for Name: conformance_rest_resource_operation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_resource_operation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, documentation) FROM stdin;
\.


--
-- Data for Name: conformance_rest_resource_profile; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_resource_profile (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_rest_resource_search_param; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_resource_search_param (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type, target, chain, documentation, name, definition) FROM stdin;
\.


--
-- Data for Name: conformance_rest_security; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_security (id, _type, _unknown_attributes, parent_id, resource_id, container_id, cors, description) FROM stdin;
\.


--
-- Data for Name: conformance_rest_security_certificate; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_security_certificate (id, _type, _unknown_attributes, parent_id, resource_id, container_id, blob, type) FROM stdin;
\.


--
-- Data for Name: conformance_rest_security_service; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_security_service (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: conformance_rest_security_service_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_security_service_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: conformance_rest_security_service_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_rest_security_service_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: conformance_software; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_software (id, _type, _unknown_attributes, parent_id, resource_id, container_id, release_date, version, name) FROM stdin;
\.


--
-- Data for Name: conformance_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: conformance_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: conformance_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY conformance_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: contact; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY contact (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: contact_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY contact_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: device; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device (id, _type, _unknown_attributes, resource_type, language, container_id, expiry, lot_number, udi, version, model, manufacturer, url) FROM stdin;
\.


--
-- Data for Name: device_contact; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_contact (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: device_contact_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_contact_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: device_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: device_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: device_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report (id, _type, _unknown_attributes, resource_type, language, container_id, instant) FROM stdin;
\.


--
-- Data for Name: device_observation_report_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: device_observation_report_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: device_observation_report_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel_metric; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel_metric (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_channel_metric_observa; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_channel_metric_observa (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: device_observation_report_virtual_device_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_observation_report_virtual_device_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_owner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_owner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: device_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: device_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: device_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: device_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY device_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order (id, _type, _unknown_attributes, resource_type, language, container_id, priority, status, clinical_notes) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, date_time) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_event_actor; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_event_actor (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_event_description; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_event_description (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_event_description_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_event_description_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_order_event_description_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_event_description_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_body_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_body_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_body_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_body_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_body_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_body_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_item_specimen; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_item_specimen (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_orderer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_orderer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_specimen; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_specimen (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_order_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_order_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: diagnostic_report; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report (id, _type, _unknown_attributes, resource_type, language, container_id, status, issued, diagnostic_date_time, conclusion) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_coded_diagnosis; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_coded_diagnosis (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_coded_diagnosis_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_coded_diagnosis_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_report_coded_diagnosis_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_coded_diagnosis_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_diagnostic_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_diagnostic_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: diagnostic_report_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: diagnostic_report_image; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_image (id, _type, _unknown_attributes, parent_id, resource_id, container_id, comment) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_image_link; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_image_link (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_imaging_study; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_imaging_study (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_name_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_name_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_report_name_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_name_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_performer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_performer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_presented_form; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_presented_form (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_request_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_request_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_result; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_result (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_service_category; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_service_category (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_service_category_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_service_category_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: diagnostic_report_service_category_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_service_category_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_specimen; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_specimen (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: diagnostic_report_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY diagnostic_report_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: document_manifest; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest (id, _type, _unknown_attributes, resource_type, language, container_id, status, created, description, source) FROM stdin;
\.


--
-- Data for Name: document_manifest_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_confidentiality; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_confidentiality (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_manifest_confidentiality_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_confidentiality_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_manifest_confidentiality_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_confidentiality_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_content; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_content (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: document_manifest_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: document_manifest_master_identifier; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_master_identifier (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: document_manifest_master_identifier_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_master_identifier_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_master_identifier_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_master_identifier_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: document_manifest_recipient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_recipient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_supercedes; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_supercedes (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_manifest_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: document_manifest_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_manifest_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_manifest_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_manifest_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference (id, _type, _unknown_attributes, resource_type, language, container_id, primary_language, status, mime_type, created, indexed, size, hash, description, policy_manager, location, format) FROM stdin;
\.


--
-- Data for Name: document_reference_authenticator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_authenticator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_class; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_class (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_class_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_class_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_class_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_class_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_confidentiality; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_confidentiality (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_confidentiality_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_confidentiality_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_confidentiality_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_confidentiality_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_context; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: document_reference_context_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_context_event_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_event_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_context_event_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_event_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_context_facility_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_facility_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_context_facility_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_facility_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_context_facility_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_facility_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_context_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_context_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: document_reference_custodian; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_custodian (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_doc_status; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_doc_status (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_doc_status_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_doc_status_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_doc_status_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_doc_status_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: document_reference_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: document_reference_master_identifier; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_master_identifier (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: document_reference_master_identifier_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_master_identifier_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_master_identifier_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_master_identifier_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: document_reference_relates_to; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_relates_to (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code) FROM stdin;
\.


--
-- Data for Name: document_reference_relates_to_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_relates_to_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_service; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_service (id, _type, _unknown_attributes, parent_id, resource_id, container_id, address) FROM stdin;
\.


--
-- Data for Name: document_reference_service_parameter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_service_parameter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, name) FROM stdin;
\.


--
-- Data for Name: document_reference_service_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_service_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_service_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_service_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_service_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_service_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: document_reference_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: document_reference_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: document_reference_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: document_reference_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY document_reference_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter (id, _type, _unknown_attributes, resource_type, language, container_id, class, status) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, re_admission) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_accomodation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_accomodation (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_accomodation_bed; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_accomodation_bed (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_accomodation_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_accomodation_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_admit_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_admit_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_admit_source_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_admit_source_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_admit_source_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_admit_source_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_destination; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_destination (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_diet; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_diet (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_diet_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_diet_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_diet_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_diet_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_discharge_diagnosis; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_discharge_diagnosis (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_discharge_disposition; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_discharge_disposition (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_discharge_disposition_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_discharge_disposition_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_discharge_disposition_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_discharge_disposition_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_origin; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_origin (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_pre_admission_identifier; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_pre_admission_identifier (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_pre_admission_identifier_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_pre_admission_identifier_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_pre_admission_identifier_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_pre_admission_identifier_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_arrangement; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_arrangement (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_arrangement_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_arrangement_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_arrangement_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_arrangement_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_courtesy; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_courtesy (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_courtesy_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_courtesy_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_hospitalization_special_courtesy_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_hospitalization_special_courtesy_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: encounter_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_indication; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_indication (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: encounter_loc_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_loc_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_loc_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_loc_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_part_of; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_part_of (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_participant; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_participant (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: encounter_participant_individual; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_participant_individual (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_participant_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_participant_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_participant_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_participant_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_participant_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_participant_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: encounter_priority; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_priority (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_priority_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_priority_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_priority_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_priority_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_service_provider; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_service_provider (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: encounter_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: encounter_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: encounter_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: encounter_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY encounter_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history (id, _type, _unknown_attributes, resource_type, language, container_id, note) FROM stdin;
\.


--
-- Data for Name: family_history_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: family_history_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: family_history_relation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, deceased_boolean, born_date, deceased_date, note, deceased_string, born_string, name) FROM stdin;
\.


--
-- Data for Name: family_history_relation_born_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_born_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition (id, _type, _unknown_attributes, parent_id, resource_id, container_id, note, onset_string) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_onset_range; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_onset_range (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_onset_range_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_onset_range_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_onset_range_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_onset_range_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_outcome; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_outcome (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_outcome_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_outcome_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_outcome_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_outcome_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: family_history_relation_condition_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_condition_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history_relation_deceased_range; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_deceased_range (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: family_history_relation_deceased_range_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_deceased_range_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: family_history_relation_deceased_range_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_deceased_range_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: family_history_relation_relationship; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_relationship (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: family_history_relation_relationship_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_relationship_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: family_history_relation_relationship_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_relation_relationship_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: family_history_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY family_history_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: group; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY "group" (id, _type, _unknown_attributes, resource_type, language, container_id, actual, type, quantity, name) FROM stdin;
\.


--
-- Data for Name: group_characteristic; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic (id, _type, _unknown_attributes, parent_id, resource_id, container_id, exclude, value_boolean) FROM stdin;
\.


--
-- Data for Name: group_characteristic_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: group_characteristic_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: group_characteristic_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_range; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_range (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_range_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_range_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: group_characteristic_value_range_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_characteristic_value_range_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: group_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: group_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: group_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: group_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: group_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: group_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: group_member; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_member (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: group_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY group_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: human_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY human_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: human_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY human_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: imaging_study; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study (id, _type, _unknown_attributes, resource_type, language, container_id, modality, availability, date_time, number_of_series, number_of_instances, uid, description, clinical_information, url) FROM stdin;
\.


--
-- Data for Name: imaging_study_accession_no; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_accession_no (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: imaging_study_accession_no_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_accession_no_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_accession_no_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_accession_no_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: imaging_study_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: imaging_study_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: imaging_study_interpreter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_interpreter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_order; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_order (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_procedure; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_procedure (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imaging_study_procedure_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_procedure_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_referrer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_referrer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_series; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_series (id, _type, _unknown_attributes, parent_id, resource_id, container_id, availability, modality, date_time, number, number_of_instances, uid, description, url) FROM stdin;
\.


--
-- Data for Name: imaging_study_series_body_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_series_body_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imaging_study_series_body_site_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_series_body_site_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_series_instance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_series_instance (id, _type, _unknown_attributes, parent_id, resource_id, container_id, number, sopclass, uid, title, type, url) FROM stdin;
\.


--
-- Data for Name: imaging_study_series_instance_attachment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_series_instance_attachment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imaging_study_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imaging_study_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: imm; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm (id, _type, _unknown_attributes, resource_type, language, container_id, reported, refused_indicator, expiration_date, date, lot_number) FROM stdin;
\.


--
-- Data for Name: imm_dose_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_dose_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: imm_explanation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: imm_explanation_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_explanation_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_explanation_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_explanation_refusal_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_refusal_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_explanation_refusal_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_refusal_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_explanation_refusal_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_explanation_refusal_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: imm_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: imm_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_manufacturer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_manufacturer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_performer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_performer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_reaction; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_reaction (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reported, date) FROM stdin;
\.


--
-- Data for Name: imm_reaction_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_reaction_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec (id, _type, _unknown_attributes, resource_type, language, container_id) FROM stdin;
\.


--
-- Data for Name: imm_rec_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: imm_rec_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, date, dose_number) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_date_criterion; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_date_criterion (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_date_criterion_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_date_criterion_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_date_criterion_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_date_criterion_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_date_criterion_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_date_criterion_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_forecast_status; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_forecast_status (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_forecast_status_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_forecast_status_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_forecast_status_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_forecast_status_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_protocol; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_protocol (id, _type, _unknown_attributes, parent_id, resource_id, container_id, dose_sequence, series, description) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_protocol_authority; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_protocol_authority (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_supporting_immunization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_supporting_immunization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_supporting_patient_information; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_supporting_patient_information (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_vaccine_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_vaccine_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_vaccine_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_vaccine_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_rec_recommendation_vaccine_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_recommendation_vaccine_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_rec_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_rec_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: imm_requester; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_requester (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_route; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_route (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_route_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_route_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_route_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_route_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol (id, _type, _unknown_attributes, parent_id, resource_id, container_id, dose_sequence, series_doses, series, description) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_authority; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_authority (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_status_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_status_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_target_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_target_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_vaccination_protocol_dose_target_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccination_protocol_dose_target_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: imm_vaccine_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccine_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: imm_vaccine_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccine_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: imm_vaccine_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY imm_vaccine_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list (id, _type, _unknown_attributes, resource_type, language, container_id, ordered, mode, date) FROM stdin;
\.


--
-- Data for Name: list_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: list_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: list_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_empty_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_empty_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: list_empty_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_empty_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: list_empty_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_empty_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_entry; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_entry (id, _type, _unknown_attributes, parent_id, resource_id, container_id, deleted, date) FROM stdin;
\.


--
-- Data for Name: list_entry_flag; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_entry_flag (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: list_entry_flag_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_entry_flag_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: list_entry_flag_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_entry_flag_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_entry_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_entry_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: list_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: list_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: list_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY list_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc (id, _type, _unknown_attributes, resource_type, language, container_id, status, mode, name, description) FROM stdin;
\.


--
-- Data for Name: loc_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: loc_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: loc_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: loc_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: loc_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: loc_managing_organization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_managing_organization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: loc_part_of; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_part_of (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: loc_physical_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_physical_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: loc_physical_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_physical_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: loc_physical_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_physical_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: loc_position; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_position (id, _type, _unknown_attributes, parent_id, resource_id, container_id, altitude, latitude, longitude) FROM stdin;
\.


--
-- Data for Name: loc_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: loc_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: loc_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: loc_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: loc_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: loc_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY loc_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med (id, _type, _unknown_attributes, resource_type, language, container_id, is_brand, kind, name) FROM stdin;
\.


--
-- Data for Name: med_adm; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm (id, _type, _unknown_attributes, resource_type, language, container_id, was_not_given, status) FROM stdin;
\.


--
-- Data for Name: med_adm_device; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_device (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage (id, _type, _unknown_attributes, parent_id, resource_id, container_id, as_needed_boolean, timing_date_time) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_as_needed_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_as_needed_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_as_needed_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_as_needed_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_as_needed_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_max_dose_per_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_max_dose_per_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_max_dose_per_period_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_max_dose_per_period_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_max_dose_per_period_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_max_dose_per_period_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_rate; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_rate (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_rate_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_rate_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_rate_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_rate_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_route; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_route (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_route_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_route_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_route_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_route_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_dosage_timing_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_dosage_timing_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_adm_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: med_adm_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_adm_med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_med (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_practitioner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_practitioner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_prs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_prs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_reason_not_given; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_reason_not_given (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_adm_reason_not_given_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_reason_not_given_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_adm_reason_not_given_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_reason_not_given_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_adm_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: med_adm_when_given; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_adm_when_given (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp (id, _type, _unknown_attributes, resource_type, language, container_id, status) FROM stdin;
\.


--
-- Data for Name: med_disp_authorizing_prescription; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_authorizing_prescription (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, when_prepared, when_handed_over) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_destination; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_destination (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage (id, _type, _unknown_attributes, parent_id, resource_id, container_id, as_needed_boolean, timing_date_time) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_additional_instructions; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_additional_instructions (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_additional_instructions_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_additional_instructions_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_additional_instructions_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_additional_instructions_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_as_needed_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_as_needed_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_as_needed_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_as_needed_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_as_needed_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_max_dose_per_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_max_dose_per_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_max_dose_per_period_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_max_dose_per_period_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_max_dose_per_period_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_max_dose_per_period_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_rate; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_rate (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_rate_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_rate_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_rate_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_rate_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_route; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_route (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_route_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_route_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_route_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_route_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_timing_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_timing_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_timing_schedule; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_timing_schedule (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_timing_schedule_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_timing_schedule_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_dosage_timing_schedule_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_dosage_timing_schedule_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_med (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_receiver; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_receiver (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_dispense_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispense_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_dispenser; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_dispenser (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: med_disp_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_disp_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_responsible_party; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_responsible_party (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_disp_substitution_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_substitution_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_disp_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_disp_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: med_manufacturer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_manufacturer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_package; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_package_container; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_container (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_package_container_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_container_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_package_container_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_container_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_package_content; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_content (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_package_content_amount; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_content_amount (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_package_content_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_package_content_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_product; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_product_form; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_form (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_product_form_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_form_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_product_form_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_form_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_product_ingredient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_ingredient (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_product_ingredient_amount; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_ingredient_amount (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_product_ingredient_amount_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_ingredient_amount_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_product_ingredient_amount_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_ingredient_amount_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_product_ingredient_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_product_ingredient_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs (id, _type, _unknown_attributes, resource_type, language, container_id, status, date_written) FROM stdin;
\.


--
-- Data for Name: med_prs_dispense; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dispense (id, _type, _unknown_attributes, parent_id, resource_id, container_id, number_of_repeats_allowed) FROM stdin;
\.


--
-- Data for Name: med_prs_dispense_med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dispense_med (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dispense_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dispense_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dispense_validity_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dispense_validity_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction (id, _type, _unknown_attributes, parent_id, resource_id, container_id, as_needed_boolean, timing_date_time, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_additional_instructions; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_additional_instructions (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_additional_instructions_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_additional_instructions_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_additional_instructions_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_additional_instructions_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_as_needed_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_as_needed_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_as_needed_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_as_needed_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_as_needed_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_dose_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_dose_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_max_dose_per_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_max_dose_per_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_max_dose_per_period_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_max_dose_per_period_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_max_dose_per_period_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_max_dose_per_period_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_rate; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_rate (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_rate_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_rate_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_rate_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_rate_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_route; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_route (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_route_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_route_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_route_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_route_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_timing_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_timing_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_timing_schedule; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_timing_schedule (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_timing_schedule_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_timing_schedule_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_prs_dosage_instruction_timing_schedule_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_dosage_instruction_timing_schedule_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: med_prs_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: med_prs_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_prs_med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_med (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_prescriber; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_prescriber (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_reason_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_reason_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_reason_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_reason_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_reason_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_reason_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_reason_resource_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_reason_resource_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_substitution; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_prs_substitution_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_substitution_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_prs_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_prs_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: med_st; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st (id, _type, _unknown_attributes, resource_type, language, container_id, was_not_given) FROM stdin;
\.


--
-- Data for Name: med_st_device; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_device (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_dosage; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage (id, _type, _unknown_attributes, parent_id, resource_id, container_id, as_needed_boolean) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_as_needed_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_as_needed_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_as_needed_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_as_needed_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_st_dosage_as_needed_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_as_needed_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_max_dose_per_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_max_dose_per_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_max_dose_per_period_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_max_dose_per_period_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_max_dose_per_period_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_max_dose_per_period_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_st_dosage_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_rate; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_rate (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_rate_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_rate_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_rate_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_rate_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_route; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_route (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_route_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_route_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_st_dosage_route_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_route_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_st_dosage_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_timing; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_timing (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: med_st_dosage_timing_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_timing_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_st_dosage_timing_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_dosage_timing_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: med_st_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: med_st_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_st_med; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_med (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_reason_not_given; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_reason_not_given (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: med_st_reason_not_given_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_reason_not_given_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: med_st_reason_not_given_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_reason_not_given_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: med_st_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: med_st_when_given; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_st_when_given (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: med_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY med_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: media; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media (id, _type, _unknown_attributes, resource_type, language, container_id, type, date_time, width, frames, length, height, device_name) FROM stdin;
\.


--
-- Data for Name: media_content; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_content (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: media_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: media_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: media_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: media_operator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_operator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: media_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: media_subtype; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_subtype (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: media_subtype_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_subtype_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: media_subtype_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_subtype_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: media_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: media_view; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_view (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: media_view_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_view_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: media_view_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY media_view_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header (id, _type, _unknown_attributes, resource_type, language, container_id, identifier, "timestamp") FROM stdin;
\.


--
-- Data for Name: message_header_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_data; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_data (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_destination; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_destination (id, _type, _unknown_attributes, parent_id, resource_id, container_id, name, endpoint) FROM stdin;
\.


--
-- Data for Name: message_header_destination_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_destination_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_enterer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_enterer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: message_header_event_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_event_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: message_header_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: message_header_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_receiver; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_receiver (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_response; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_response (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, identifier) FROM stdin;
\.


--
-- Data for Name: message_header_response_details; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_response_details (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_responsible; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_responsible (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: message_header_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, name, software, version, endpoint) FROM stdin;
\.


--
-- Data for Name: message_header_source_contact; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_source_contact (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: message_header_source_contact_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_source_contact_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: message_header_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY message_header_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: narrative; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY narrative (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: observation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation (id, _type, _unknown_attributes, resource_type, language, container_id, status, reliability, applies_date_time, issued, value_string, comments) FROM stdin;
\.


--
-- Data for Name: observation_applies_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_applies_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: observation_body_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_body_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_body_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_body_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_body_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_body_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: observation_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: observation_interpretation; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_interpretation (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_interpretation_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_interpretation_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_interpretation_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_interpretation_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_name_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_name_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_name_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_name_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_performer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_performer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_reference_range; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_age; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_age (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_age_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_age_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_age_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_age_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_meaning; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_meaning (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_reference_range_meaning_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_meaning_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_reference_range_meaning_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_reference_range_meaning_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_related; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_related (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type) FROM stdin;
\.


--
-- Data for Name: observation_related_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_related_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_specimen; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_specimen (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: observation_value_attachment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_attachment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: observation_value_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: observation_value_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: observation_value_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: observation_value_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: observation_value_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_value_ratio; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_ratio (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: observation_value_ratio_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_ratio_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_value_ratio_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_ratio_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: observation_value_sampled_data; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_sampled_data (id, _type, _unknown_attributes, parent_id, resource_id, container_id, period, factor, lower_limit, upper_limit, dimensions, data) FROM stdin;
\.


--
-- Data for Name: observation_value_sampled_data_origin; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY observation_value_sampled_data_origin (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: operation_outcome; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY operation_outcome (id, _type, _unknown_attributes, resource_type, language, container_id) FROM stdin;
\.


--
-- Data for Name: operation_outcome_issue; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY operation_outcome_issue (id, _type, _unknown_attributes, parent_id, resource_id, container_id, severity, details, location) FROM stdin;
\.


--
-- Data for Name: operation_outcome_issue_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY operation_outcome_issue_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: operation_outcome_issue_type_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY operation_outcome_issue_type_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: operation_outcome_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY operation_outcome_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: order; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY "order" (id, _type, _unknown_attributes, resource_type, language, container_id, date) FROM stdin;
\.


--
-- Data for Name: order_authority; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_authority (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: order_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: order_reason_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_reason_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: order_reason_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_reason_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: order_reason_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_reason_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_reason_resource_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_reason_resource_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response (id, _type, _unknown_attributes, resource_type, language, container_id, code, date, description) FROM stdin;
\.


--
-- Data for Name: order_response_authority_codeable_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_authority_codeable_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: order_response_authority_codeable_concept_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_authority_codeable_concept_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: order_response_authority_codeable_concept_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_authority_codeable_concept_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response_authority_resource_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_authority_resource_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response_fulfillment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_fulfillment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: order_response_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: order_response_request; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_request (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_response_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: order_response_who; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_response_who (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: order_when; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: order_when_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: order_when_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: order_when_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: order_when_schedule; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_schedule (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: order_when_schedule_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_schedule_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: order_when_schedule_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY order_when_schedule_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: organization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization (id, _type, _unknown_attributes, resource_type, language, container_id, active, name) FROM stdin;
\.


--
-- Data for Name: organization_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: organization_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_contact; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: organization_contact_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: organization_contact_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_contact_gender; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_gender (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: organization_contact_gender_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_gender_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: organization_contact_gender_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_gender_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: organization_contact_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: organization_contact_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_contact_purpose; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_purpose (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: organization_contact_purpose_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_purpose_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: organization_contact_purpose_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_purpose_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: organization_contact_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: organization_contact_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_contact_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: organization_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: organization_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: organization_part_of; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_part_of (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: organization_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: organization_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: organization_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: organization_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: organization_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: organization_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY organization_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: other; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other (id, _type, _unknown_attributes, resource_type, language, container_id, created) FROM stdin;
\.


--
-- Data for Name: other_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: other_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: other_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: other_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: other_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: other_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: other_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: other_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: other_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY other_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient (id, _type, _unknown_attributes, resource_type, language, container_id, deceased_boolean, multiple_birth_boolean, active, birth_date, deceased_date_time, multiple_birth_integer) FROM stdin;
\.


--
-- Data for Name: patient_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: patient_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_animal; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: patient_animal_breed; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_breed (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_animal_breed_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_breed_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_animal_breed_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_breed_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_animal_gender_status; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_gender_status (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_animal_gender_status_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_gender_status_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_animal_gender_status_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_gender_status_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_animal_species; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_species (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_animal_species_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_species_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_animal_species_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_animal_species_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_care_provider; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_care_provider (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_communication; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_communication (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_communication_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_communication_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_communication_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_communication_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_contact; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: patient_contact_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: patient_contact_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_contact_gender; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_gender (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_contact_gender_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_gender_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_contact_gender_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_gender_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_contact_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: patient_contact_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_contact_organization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_organization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_contact_relationship; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_relationship (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_contact_relationship_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_relationship_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_contact_relationship_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_relationship_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_contact_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: patient_contact_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_contact_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_gender; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_gender (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_gender_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_gender_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_gender_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_gender_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: patient_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_link; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_link (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type) FROM stdin;
\.


--
-- Data for Name: patient_link_other; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_link_other (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_managing_organization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_managing_organization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_marital_status; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_marital_status (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: patient_marital_status_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_marital_status_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: patient_marital_status_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_marital_status_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: patient_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: patient_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_photo; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_photo (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: patient_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: patient_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: patient_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY patient_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner (id, _type, _unknown_attributes, resource_type, language, container_id, birth_date) FROM stdin;
\.


--
-- Data for Name: practitioner_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: practitioner_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_communication; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_communication (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: practitioner_communication_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_communication_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: practitioner_communication_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_communication_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_gender; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_gender (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: practitioner_gender_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_gender_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: practitioner_gender_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_gender_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: practitioner_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: practitioner_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_organization; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_organization (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_photo; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_photo (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: practitioner_qualification; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: practitioner_qualification_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: practitioner_qualification_code_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification_code_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: practitioner_qualification_code_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification_code_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_qualification_issuer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification_issuer (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_qualification_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_qualification_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_role; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_role (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: practitioner_role_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_role_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: practitioner_role_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_role_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_specialty; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_specialty (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: practitioner_specialty_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_specialty_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: practitioner_specialty_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_specialty_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: practitioner_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: practitioner_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: practitioner_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY practitioner_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: procedure; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure (id, _type, _unknown_attributes, resource_type, language, container_id, outcome, follow_up, notes) FROM stdin;
\.


--
-- Data for Name: procedure_body_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_body_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: procedure_body_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_body_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: procedure_body_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_body_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_complication; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_complication (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: procedure_complication_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_complication_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: procedure_complication_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_complication_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_date; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_date (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: procedure_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: procedure_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: procedure_indication; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_indication (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: procedure_indication_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_indication_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: procedure_indication_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_indication_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_performer; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_performer (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: procedure_performer_person; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_performer_person (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_performer_role; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_performer_role (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: procedure_performer_role_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_performer_role_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: procedure_performer_role_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_performer_role_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_related_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_related_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type) FROM stdin;
\.


--
-- Data for Name: procedure_related_item_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_related_item_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_report; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_report (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: procedure_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: procedure_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: procedure_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: procedure_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY procedure_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: profile; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile (id, _type, _unknown_attributes, resource_type, language, container_id, experimental, status, date, fhir_version, identifier, version, name, publisher, description, requirements) FROM stdin;
\.


--
-- Data for Name: profile_code; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_code (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: profile_code_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_code_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: profile_extension_defn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_extension_defn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, context_type, display, context) FROM stdin;
\.


--
-- Data for Name: profile_mapping; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_mapping (id, _type, _unknown_attributes, parent_id, resource_id, container_id, identity, name, comments, uri) FROM stdin;
\.


--
-- Data for Name: profile_query; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_query (id, _type, _unknown_attributes, parent_id, resource_id, container_id, name, documentation) FROM stdin;
\.


--
-- Data for Name: profile_structure; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure (id, _type, _unknown_attributes, parent_id, resource_id, container_id, publish, type, name, purpose) FROM stdin;
\.


--
-- Data for Name: profile_structure_element; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element (id, _type, _unknown_attributes, parent_id, resource_id, container_id, representation, path, name) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition (id, _type, _unknown_attributes, parent_id, resource_id, container_id, is_modifier, must_support, condition, min, max_length, short, formal, comments, requirements, synonym, max, name_reference) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition_binding; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition_binding (id, _type, _unknown_attributes, parent_id, resource_id, container_id, is_extensible, conformance, name, description, reference_uri) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition_binding_reference_resource; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition_binding_reference_resource (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition_constraint; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition_constraint (id, _type, _unknown_attributes, parent_id, resource_id, container_id, severity, key, name, human, xpath) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition_mapping; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition_mapping (id, _type, _unknown_attributes, parent_id, resource_id, container_id, identity, map) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_definition_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_definition_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, aggregation, code, profile) FROM stdin;
\.


--
-- Data for Name: profile_structure_element_slicing; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_element_slicing (id, _type, _unknown_attributes, parent_id, resource_id, container_id, ordered, rules, discriminator) FROM stdin;
\.


--
-- Data for Name: profile_structure_search_param; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_structure_search_param (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type, target, xpath, name, documentation) FROM stdin;
\.


--
-- Data for Name: profile_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: profile_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: profile_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY profile_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: provenance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance (id, _type, _unknown_attributes, resource_type, language, container_id, recorded, integrity_signature, policy) FROM stdin;
\.


--
-- Data for Name: provenance_agent; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_agent (id, _type, _unknown_attributes, parent_id, resource_id, container_id, display, reference) FROM stdin;
\.


--
-- Data for Name: provenance_agent_role; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_agent_role (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: provenance_agent_role_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_agent_role_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_agent_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_agent_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: provenance_agent_type_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_agent_type_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_entity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_entity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, role, display, reference) FROM stdin;
\.


--
-- Data for Name: provenance_entity_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_entity_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: provenance_entity_type_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_entity_type_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_loc; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_loc (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: provenance_reason; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_reason (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: provenance_reason_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_reason_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: provenance_reason_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_reason_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: provenance_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY provenance_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: query; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY query (id, _type, _unknown_attributes, resource_type, language, container_id, identifier) FROM stdin;
\.


--
-- Data for Name: query_response; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY query_response (id, _type, _unknown_attributes, parent_id, resource_id, container_id, outcome, total, identifier) FROM stdin;
\.


--
-- Data for Name: query_response_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY query_response_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: query_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY query_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: questionnaire; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire (id, _type, _unknown_attributes, resource_type, language, container_id, status, authored) FROM stdin;
\.


--
-- Data for Name: questionnaire_author; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_author (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_encounter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_encounter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_group; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group (id, _type, _unknown_attributes, parent_id, resource_id, container_id, header, text) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_name_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_name_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: questionnaire_group_name_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_name_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question (id, _type, _unknown_attributes, parent_id, resource_id, container_id, answer_boolean, answer_date, answer_date_time, answer_decimal, answer_instant, answer_integer, answer_string, text, remarks) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_choice; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_choice (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_choice_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_choice_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_name_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_name_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_name_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_name_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_question_options; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_question_options (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_group_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_group_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: questionnaire_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: questionnaire_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: questionnaire_name_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_name_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: questionnaire_name_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_name_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: questionnaire_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY questionnaire_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: range; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY range (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: range_high; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY range_high (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: range_low; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY range_low (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: ratio; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY ratio (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: ratio_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY ratio_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: ratio_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY ratio_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: related_person; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person (id, _type, _unknown_attributes, resource_type, language, container_id) FROM stdin;
\.


--
-- Data for Name: related_person_address; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_address (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, line, city, state, zip, country) FROM stdin;
\.


--
-- Data for Name: related_person_address_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_address_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: related_person_gender; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_gender (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: related_person_gender_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_gender_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: related_person_gender_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_gender_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: related_person_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: related_person_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: related_person_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: related_person_name; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_name (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, text, family, given, prefix, suffix) FROM stdin;
\.


--
-- Data for Name: related_person_name_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_name_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: related_person_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: related_person_photo; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_photo (id, _type, _unknown_attributes, parent_id, resource_id, container_id, content_type, language, data, url, size, hash, title) FROM stdin;
\.


--
-- Data for Name: related_person_relationship; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_relationship (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: related_person_relationship_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_relationship_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: related_person_relationship_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_relationship_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: related_person_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: related_person_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: related_person_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY related_person_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: resource; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource (id, _type, _unknown_attributes, resource_type, language, container_id) FROM stdin;
\.


--
-- Data for Name: resource_component; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource_component (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: resource_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY resource_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: sampled_data; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY sampled_data (id, _type, _unknown_attributes, parent_id, resource_id, container_id, period, factor, lower_limit, upper_limit, dimensions, data) FROM stdin;
\.


--
-- Data for Name: sampled_data_origin; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY sampled_data_origin (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY schedule (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: schedule_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY schedule_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: schedule_repeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY schedule_repeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: schedulerepeat; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY schedulerepeat (id, _type, _unknown_attributes, parent_id, resource_id, container_id, frequency, "when", duration, units, count, "end") FROM stdin;
\.


--
-- Data for Name: security_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event (id, _type, _unknown_attributes, resource_type, language, container_id) FROM stdin;
\.


--
-- Data for Name: security_event_event; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event (id, _type, _unknown_attributes, parent_id, resource_id, container_id, outcome, action, date_time, outcome_desc) FROM stdin;
\.


--
-- Data for Name: security_event_event_subtype; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_subtype (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: security_event_event_subtype_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_subtype_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_event_subtype_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_subtype_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_event_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: security_event_event_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_event_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_event_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_object; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object (id, _type, _unknown_attributes, parent_id, resource_id, container_id, query, lifecycle, role, type, name, description) FROM stdin;
\.


--
-- Data for Name: security_event_object_detail; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_detail (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, type) FROM stdin;
\.


--
-- Data for Name: security_event_object_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: security_event_object_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_object_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: security_event_object_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_object_sensitivity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_sensitivity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: security_event_object_sensitivity_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_sensitivity_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_object_sensitivity_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_object_sensitivity_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_participant; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant (id, _type, _unknown_attributes, parent_id, resource_id, container_id, requestor, user_id, alt_id, name) FROM stdin;
\.


--
-- Data for Name: security_event_participant_media; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_media (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_participant_media_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_media_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_participant_network; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_network (id, _type, _unknown_attributes, parent_id, resource_id, container_id, type, identifier) FROM stdin;
\.


--
-- Data for Name: security_event_participant_reference; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_reference (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_participant_role; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_role (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: security_event_participant_role_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_role_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_participant_role_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_participant_role_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, site, identifier) FROM stdin;
\.


--
-- Data for Name: security_event_source_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_source_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: security_event_source_type_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_source_type_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: security_event_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY security_event_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: specimen; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen (id, _type, _unknown_attributes, resource_type, language, container_id, received_time) FROM stdin;
\.


--
-- Data for Name: specimen_accession_identifier; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_accession_identifier (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: specimen_accession_identifier_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_accession_identifier_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_accession_identifier_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_accession_identifier_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: specimen_collection; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection (id, _type, _unknown_attributes, parent_id, resource_id, container_id, collected_date_time, comment) FROM stdin;
\.


--
-- Data for Name: specimen_collection_collected_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_collected_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: specimen_collection_collector; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_collector (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_collection_method; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_method (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: specimen_collection_method_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_method_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: specimen_collection_method_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_method_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_collection_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: specimen_collection_source_site; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_source_site (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: specimen_collection_source_site_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_source_site_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: specimen_collection_source_site_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_collection_source_site_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_container; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container (id, _type, _unknown_attributes, parent_id, resource_id, container_id, description) FROM stdin;
\.


--
-- Data for Name: specimen_container_additive; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_additive (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_container_capacity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_capacity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: specimen_container_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: specimen_container_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_container_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: specimen_container_specimen_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_specimen_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: specimen_container_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: specimen_container_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: specimen_container_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_container_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: specimen_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: specimen_source; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_source (id, _type, _unknown_attributes, parent_id, resource_id, container_id, relationship) FROM stdin;
\.


--
-- Data for Name: specimen_source_target; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_source_target (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_subject; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_subject (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: specimen_treatment; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_treatment (id, _type, _unknown_attributes, parent_id, resource_id, container_id, description) FROM stdin;
\.


--
-- Data for Name: specimen_treatment_additive; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_treatment_additive (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_treatment_procedure; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_treatment_procedure (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: specimen_treatment_procedure_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_treatment_procedure_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: specimen_treatment_procedure_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_treatment_procedure_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: specimen_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: specimen_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: specimen_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY specimen_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: substance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance (id, _type, _unknown_attributes, resource_type, language, container_id, description) FROM stdin;
\.


--
-- Data for Name: substance_ingredient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_ingredient (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: substance_ingredient_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_ingredient_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id) FROM stdin;
\.


--
-- Data for Name: substance_ingredient_quantity_denominator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_ingredient_quantity_denominator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: substance_ingredient_quantity_numerator; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_ingredient_quantity_numerator (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: substance_ingredient_substance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_ingredient_substance (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: substance_instance; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_instance (id, _type, _unknown_attributes, parent_id, resource_id, container_id, expiry) FROM stdin;
\.


--
-- Data for Name: substance_instance_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_instance_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: substance_instance_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_instance_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: substance_instance_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_instance_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: substance_instance_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_instance_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: substance_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: substance_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: substance_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: substance_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY substance_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply (id, _type, _unknown_attributes, resource_type, language, container_id, status) FROM stdin;
\.


--
-- Data for Name: supply_dispense; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status) FROM stdin;
\.


--
-- Data for Name: supply_dispense_destination; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_destination (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: supply_dispense_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: supply_dispense_quantity; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_quantity (id, _type, _unknown_attributes, parent_id, resource_id, container_id, value, comparator, units, system, code) FROM stdin;
\.


--
-- Data for Name: supply_dispense_receiver; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_receiver (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_supplied_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_supplied_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_supplier; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_supplier (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_type; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_type (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: supply_dispense_type_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_type_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: supply_dispense_type_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_type_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_dispense_when_handed_over; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_when_handed_over (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: supply_dispense_when_prepared; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_dispense_when_prepared (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: supply_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: supply_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: supply_kind; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_kind (id, _type, _unknown_attributes, parent_id, resource_id, container_id, text) FROM stdin;
\.


--
-- Data for Name: supply_kind_cd; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_kind_cd (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, version, code, display, "primary") FROM stdin;
\.


--
-- Data for Name: supply_kind_cd_vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_kind_cd_vs (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_ordered_item; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_ordered_item (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_patient; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_patient (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: supply_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY supply_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Data for Name: vs; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs (id, _type, _unknown_attributes, resource_type, language, container_id, experimental, extensible, status, date, publisher, name, copyright, description, version, identifier) FROM stdin;
\.


--
-- Data for Name: vs_compose; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_compose (id, _type, _unknown_attributes, parent_id, resource_id, container_id, import) FROM stdin;
\.


--
-- Data for Name: vs_compose_include; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_compose_include (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, version, system) FROM stdin;
\.


--
-- Data for Name: vs_compose_include_filter; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_compose_include_filter (id, _type, _unknown_attributes, parent_id, resource_id, container_id, op, property, value) FROM stdin;
\.


--
-- Data for Name: vs_define; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_define (id, _type, _unknown_attributes, parent_id, resource_id, container_id, case_sensitive, version, system) FROM stdin;
\.


--
-- Data for Name: vs_define_concept; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_define_concept (id, _type, _unknown_attributes, parent_id, resource_id, container_id, abstract, code, definition, display) FROM stdin;
\.


--
-- Data for Name: vs_expansion; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_expansion (id, _type, _unknown_attributes, parent_id, resource_id, container_id, "timestamp") FROM stdin;
\.


--
-- Data for Name: vs_expansion_contains; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_expansion_contains (id, _type, _unknown_attributes, parent_id, resource_id, container_id, code, display, system) FROM stdin;
\.


--
-- Data for Name: vs_expansion_idn; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_expansion_idn (id, _type, _unknown_attributes, parent_id, resource_id, container_id, use, label, system, value) FROM stdin;
\.


--
-- Data for Name: vs_expansion_idn_assigner; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_expansion_idn_assigner (id, _type, _unknown_attributes, parent_id, resource_id, container_id, reference, display) FROM stdin;
\.


--
-- Data for Name: vs_expansion_idn_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_expansion_idn_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: vs_telecom; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_telecom (id, _type, _unknown_attributes, parent_id, resource_id, container_id, system, value, use) FROM stdin;
\.


--
-- Data for Name: vs_telecom_period; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_telecom_period (id, _type, _unknown_attributes, parent_id, resource_id, container_id, start, "end") FROM stdin;
\.


--
-- Data for Name: vs_text; Type: TABLE DATA; Schema: fhir; Owner: -
--

COPY vs_text (id, _type, _unknown_attributes, parent_id, resource_id, container_id, status, div) FROM stdin;
\.


--
-- Name: resource_component_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY resource_component
    ADD CONSTRAINT resource_component_pkey PRIMARY KEY (id);


--
-- Name: resource_pkey; Type: CONSTRAINT; Schema: fhir; Owner: -; Tablespace: 
--

ALTER TABLE ONLY resource
    ADD CONSTRAINT resource_pkey PRIMARY KEY (id);


--
-- Name: resource_component_container_id_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY resource_component
    ADD CONSTRAINT resource_component_container_id_fkey FOREIGN KEY (container_id) REFERENCES resource(id);


--
-- Name: resource_component_parent_id_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY resource_component
    ADD CONSTRAINT resource_component_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES resource_component(id);


--
-- Name: resource_component_resource_id_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY resource_component
    ADD CONSTRAINT resource_component_resource_id_fkey FOREIGN KEY (resource_id) REFERENCES resource(id);


--
-- Name: resource_container_id_fkey; Type: FK CONSTRAINT; Schema: fhir; Owner: -
--

ALTER TABLE ONLY resource
    ADD CONSTRAINT resource_container_id_fkey FOREIGN KEY (container_id) REFERENCES resource(id);


--
-- PostgreSQL database dump complete
--

