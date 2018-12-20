use strict;
use Test::Exception;
use Test::More;
use Test::Deep;

use lib 't';
use Data::Dumper;
use Support::TestSetup;

Support::TestSetup::login();

use_ok 'SL::DB::PriceRuleMacro';
use_ok 'SL::Controller::PriceRuleMacro';


my @test_cases = (
{ json =>
   '{
      "name": "SEV0815 Kundentyp-Rabatt",
      "priority": 3,
      "obsolete": 0,
      "format_version": 1,
      "type": "customer",
      "condition": {
        "type": "container_and",
        "condition": [
          {
            "type": "part",
            "id": 815
          },
          {
            "type": "business",
            "id": 3234
          }
        ]
      },
      "action": {
        "type": "simple_action",
        "discount": 4.00
      }
    }',
  digest => [
     "-4-business-3234-part-815-",
  ],
  name => 'simple business discount',
},
{ json => '
{
  "name": "SEV0815 Kundentyp-Rabatt",
  "priority": 3,
  "obsolete": 1,
  "format_version": 1,
  "type": "vendor",
  "condition": {
    "type": "container_and",
    "condition": [
      {
        "type": "part",
        "id": 815
      },
      {
        "type": "container_or",
        "condition": [
          {
            "type": "business",
            "id": 3234
          },
          {
            "type": "business",
            "id": 8473
          },
          {
            "type": "business",
            "id": 382
          }
        ]
      }
    ]
  },
  "action": {
    "type": "simple_action",
    "discount": 4.00
  }
}',
  digest => [
     '-4-business-3234-part-815-',
     '-4-business-382-part-815-',
     '-4-business-8473-part-815-'
  ],
  name => 'complex business discount',
},
{ json => '
  {
	"name": "SEV0815 Kundentyp-Rabatt",
	"priority": 3,
	"obsolete": 1,
	"format_version": 1,
    "type": "customer",
	"condition": {
	  "type": "container_and",
	  "condition": [
		{
		  "type": "container_or",
		  "condition": [
			{
			  "type": "part",
			  "id": 815
			},
			{
			  "type": "part",
			  "id": 376
			}
		  ]
		},
		{
		  "type": "container_or",
		  "condition": [
			{
			  "type": "business",
			  "id": 3234
			},
			{
			  "type": "business",
			  "id": 2573
			},
			{
			  "type": "business",
			  "id": 472
			}
		  ]
		}
	  ]
	},
	"action": {
	  "type": "simple_action",
	  "discount": 4.00
	}
  }',
  digest => [
	'-4-business-2573-part-376-',
	'-4-business-2573-part-815-',
	'-4-business-3234-part-376-',
	'-4-business-3234-part-815-',
	'-4-business-472-part-376-',
	'-4-business-472-part-815-'
  ],
  name => 'very complex business discount',
},
{ json => '
  {
	"name": "SEV0815 Kundentyp-Rabatt",
	"priority": 3,
	"obsolete": 0,
	"format_version": 1,
    "type": "vendor",
	"condition": {
	  "type": "part",
	  "id": 815
	},
	"action": {
	  "type": "price_scale_action",
	  "conditional_action": [
		{
		  "condition": {
            "type": "qty_range",
			"min": 0.00,
			"max": 9.00
		  },
		  "action": {
			"type": "simple_action",
			"price": 1100.00
		  }
		},
		{
		  "condition": {
            "type": "qty_range",
			"min": 10.00,
			"max": 99.00
		  },
		  "action": {
			"type": "simple_action",
			"price": 1000.00
		  }
		},
		{
		  "condition": {
            "type": "qty_range",
			"min": 100
		  },
		  "action": {
			"type": "simple_action",
			"price": 900.00
		  }
		}
	  ]
	}
  }',
  digest => [
     '1000--part-815-qtyge--10qtyle--99',
     '1100--part-815-qtyge--0qtyle--9',
     '900--part-815-qtyge--100qtyle---'
  ],
  name => 'qty range action',
},
{ json => '
  {
	"name": "SRV0815 Warengruppen -> Kundengruppen",
	"priority": 3,
	"obsolete": 0,
    "type": "customer",
	"format_version": 1,
	"condition": {
	  "type": "container_or",
	  "condition": [
		{
		  "type": "partsgroup",
		  "id": 428
		},
		{
		  "type": "partsgroup",
		  "id": 8437
		}
	  ]
	},
	"action": {
	  "type": "price_scale_action",
	  "conditional_action": [
		{
		  "condition": {
			"type": "business",
			"id": 42
		  },
		  "action": {
			"type": "simple_action",
			"discount": 2.00
		  }
		},
		{
		  "condition": {
			"type": "business",
			"id": 6345
		  },
		  "action": {
			"type": "simple_action",
			"discount": 3.00
		  }
		},
		{
		  "condition": {
			"type": "business",
			"id": 2344
		  },
		  "action": {
			"type": "simple_action",
			"discount": 4.00
		  }
		}
	  ]
	}
  }',
  digest => [
    '-2-business-42-partsgroup-428-',
    '-2-business-42-partsgroup-8437-',
    '-3-business-6345-partsgroup-428-',
    '-3-business-6345-partsgroup-8437-',
    '-4-business-2344-partsgroup-428-',
    '-4-business-2344-partsgroup-8437-',
  ],
  name => 'complex condition + price scale',
},
{ json =>
   '{
      "name": "SEV0815 Kundentyp-Rabatt",
      "priority": 3,
      "obsolete": 0,
      "format_version": 1,
      "type": "customer",
      "condition": {
        "type": "container_and",
        "condition": [
          {
            "type": "business",
            "id": [ 815, 918, 428, 843 ]
          }
        ]
      },
      "action": {
        "type": "simple_action",
        "discount": 4.00
      }
    }',
  digest => [
    '-4-business-428-',
    '-4-business-815-',
    '-4-business-843-',
    '-4-business-918-'
  ],
  name => 'simple business with array of ids',
},
{ json =>
   '{
      "name": "Test simple parsed attrs",
      "priority": 3,
      "obsolete": 0,
      "format_version": 1,
      "type": "customer",
      "condition": {
        "type": "container_and",
        "condition": [
          {
            "type": "qty",
            "op": "eq",
            "num_as_number": "23,14"
          },
          {
            "type": "reqdate",
            "date_as_date": "07.12.2018",
            "op": "lt"
          }
        ]
      },
      "action": {
        "type": "simple_action",
        "discount_as_number": "4,00"
      }
    }',
  digest => [
     "-4-qtyeq--23.14reqdatelt2018-12-07--",
  ],
  no_roundtrip => 1,
  name => 'simple business discount',
},
{ json =>
  '{
    "action": {
        "price": "321",
        "discount": null,
        "reduction": null,
        "type": "simple_action"
    },
    "condition": {
        "type": "container_and",
        "condition": [{
            "type": "container_and",
            "condition": [
              {
                "type": "vendor",
                "id": 126564
              },
              {
                "type": "ve",
                "op": "gt",
                "num_as_number": 14
              }
            ]
        }]
    },
    "format_version": "1",
    "name": "Test",
    "notes": "Dies ist ein Kommentar",
    "obsolete": "0",
    "priority": "3",
    "type": "customer"
  }',
  digest => [
    '321--vegt--14vendor-126564-',
  ],
  name => 'null in discount',
  no_roundtrip => 1,
},
);

$::request->type('json');
open my $stdout_fh, '>', \my $stdout or die;


for my $case (@test_cases) {
  my $m = SL::DB::PriceRuleMacro->new(json_definition => $case->{json});

  is_deeply $m->definition, $m->parsed_definition->as_tree, "$case->{name}: parse_definition and as_tree roundtrip"
    unless $case->{no_roundtrip};
  cmp_deeply [ map { $_->digest } $m->parsed_definition->price_rules ], bag(@{ $case->{digest} }), "$case->{name}: digests match";

  {
    $stdout = undef;
    local *STDOUT = $stdout_fh;

    my $c = SL::Controller::PriceRuleMacro->new;

    $::form->{price_rule_macro} = {
      json_definition => $case->{json},
      name            => $case->{name},
      type            => 'customer',
    };

    my $result;
    eval {
      my $json_result = $c->action_save;
      $result      = SL::JSON::from_json("$json_result");
      ok $result->{id}, "$case->{name}: save";
      1;
    } or do {
      ok 0, "$case->{name} - exception: $@";
    };

    $m = SL::DB::PriceRuleMacro->new(id => $result->{id})->load;

    isa_ok $m, 'SL::DB::PriceRuleMacro', "$case->{name}: load";

    cmp_deeply [ map { $_->digest } $m->parsed_definition->price_rules ], bag(@{ $case->{digest} }), "$case->{name}: digests still match";
  }
}

done_testing();
