create schema fhir;
create or replace function fhir.py_init() returns void language plpythonu as $$
  if '__fhir__init__' not in GD:
    def underscore(x):
      return plpy.execute("select fhir.underscore('%s')" % x)[0]['underscore']

    def prepare_path(path):
      word_aliases = {
        'capabilities': 'cap',
        'chanel': 'chnl',
        'codeable_concept': 'cc',
        'coding': 'cd',
        'identifier': 'idn',
        'immunization': 'imm',
        'immunization_recommendation': 'imm_rec',
        'location': 'loc',
        'medication': 'med',
        'medication_administration': 'med_adm',
        'medication_dispense': 'med_disp',
        'medication_prescription': 'med_prs',
        'medication_statement': 'med_st',
        'observation': 'obs',
        'prescription': 'prs',
        'recommentdaton': 'rcm',
        'resource_reference': 'res_ref',
        'value': 'val',
        'value_set': 'vs'}

      acc = []
      for nm in path:
        word = underscore(nm)
        if word in word_aliases:
          acc.append(word_aliases[word])
        else:
          acc.append(nm)

      return acc

    GD['underscore'] = underscore
    GD['prepare_path'] = prepare_path
    GD['__fhir__init__'] = True
$$;
