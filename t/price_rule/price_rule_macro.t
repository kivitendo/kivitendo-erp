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

my $format_version = SL::DB::PriceRuleMacro->latest_version;


my @test_cases = (
{ json =>
   qq'{
      "name": "SEV0815 Kundentyp-Rabatt",
      "priority": 3,
      "obsolete": 0,
      "format_version": $format_version,
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
        "type": "discount_action",
        "discount": 4.00
      }
    }',
  digest => [
     "-4-business-3234-part-815-",
  ],
  name => 'simple business discount',
},
{ json => qq'
{
  "name": "SEV0815 Kundentyp-Rabatt",
  "priority": 3,
  "obsolete": 1,
  "format_version": $format_version,
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
    "type": "discount_action",
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
{ json => qq'
  {
  "name": "SEV0815 Kundentyp-Rabatt",
  "priority": 3,
  "obsolete": 1,
  "format_version": $format_version,
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
    "type": "discount_action",
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
{ json => qq'
  {
  "name": "SEV0815 Kundentyp-Rabatt",
  "priority": 3,
  "obsolete": 0,
  "format_version": $format_version,
    "type": "vendor",
  "condition": {
    "type": "part",
    "id": 815
  },
  "action": {
    "type": "price_scale_action",
    "price_scale_action_line": [
        {
          "min": 0.00,
          "price": 1100.00
        },
        {
          "min": 10.00,
          "price": 1000.00
        },
        {
          "min": 100,
          "price": 900.00
        }
      ]
    }
  }',
  digest => [
     '1000--part-815-qtyge--10qtylt--100',
     '1100--part-815-qtyge--0qtylt--10',
     '900--part-815-qtyge--100'
  ],
  name => 'qty range action',
},
{ json => qq'
  {
  "name": "SRV0815 Warengruppen -> Kundengruppen",
  "priority": 3,
  "obsolete": 0,
    "type": "customer",
  "format_version": $format_version,
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
    "type": "action_container_and",
    "action": [
      {
        "type": "conditional_action",
        "condition": {
          "type": "business",
          "id": 42
        },
        "action": {
          "type": "discount_action",
          "discount": 2.00
        }
      },
      {
        "type": "conditional_action",
        "condition": {
          "type": "business",
          "id": 6345
        },
        "action": {
          "type": "discount_action",
          "discount": 3.00
        }
      },
      {
        "type": "conditional_action",
        "condition": {
          "type": "business",
          "id": 2344
        },
        "action": {
          "type": "discount_action",
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
   qq'{
      "name": "SEV0815 Kundentyp-Rabatt",
      "priority": 3,
      "obsolete": 0,
      "format_version": $format_version,
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
        "type": "discount_action",
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
   qq'{
      "name": "Test simple parsed attrs",
      "priority": 3,
      "obsolete": 0,
      "format_version": $format_version,
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
            "date_as_epoch": 1544140800,
            "op": "lt"
          }
        ]
      },
      "action": {
        "type": "discount_action",
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
  qq'{
    "action": {
        "price": "321",
        "type": "price_action"
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
    "format_version": "$format_version",
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
{ json =>
  qq'{
    "action": {
        "price": "321",
        "type": "price_action"
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
    "format_version": "$format_version",
    "name": "Test",
    "notes": "Dies ist ein Kommentar",
    "obsolete": "0",
    "priority": "3",
    "type": "customer"
  }',
  form => {
    'price_rule_macro.id' => '',
  },
  digest => [
    '321--vegt--14vendor-126564-',
  ],
  name => 'empty string in id',
  no_roundtrip => 1,
},
{ json =>
  qq'{
    "action": {
        "price": "321",
        "type": "price_action"
    },
    "condition": {
        "type": "container_and",
        "condition": [{
            "type": "container_and",
            "condition": [
              {
                "type": "vendor"
              },
              {
                "type": "ve",
                "op": "gt",
                "num_as_number": 14
              }
            ]
        }]
    },
    "format_version": "$format_version",
    "name": "Test",
    "notes": "Dies ist ein Kommentar",
    "obsolete": "0",
    "priority": "3",
    "type": "customer"
  }',
  dies_ok => qr/condition of type 'vendor' needs an id/,
  name => 'missing id in vendor condition',
},
{ json =>
  qq'{
    "action": {
        "price": "321",
        "type": "price_action"
    },
    "condition": {
        "type": "container_and",
        "condition": [{
            "type": "container_and",
            "condition": [
              {
                "type": "vendor",
                "id": 14
              },
              {
                "type": "ve",
                "num_as_number": 14
              }
            ]
        }]
    },
    "format_version": "$format_version",
    "name": "Test",
    "notes": "Dies ist ein Kommentar",
    "obsolete": "0",
    "priority": "3",
    "type": "customer"
  }',
  dies_ok => qr/condition of type 've' needs an op/,
  name => 'missing op in ve condition',
},
{ json =>
  qq'{
    "action": {
        "price_type": 0,
        "price_or_discount": null,
        "type": "simple_action"
    },
    "condition": {
        "type": "container_and",
        "condition": [{
            "type": "container_and",
            "condition": [
              {
                "type": "vendor",
                "id": 14
              },
              {
                "type": "ve",
                "op": "ge",
                "num_as_number": 14
              }
            ]
        }]
    },
    "format_version": "$format_version",
    "name": "Test",
    "notes": "Dies ist ein Kommentar",
    "obsolete": "0",
    "priority": "3",
    "type": "customer"
  }',
  dies_ok => qr/action of type 'simple_action' needs at least/,
  name => 'missing price/discount/reduction in action',
},
{ json =>
  qq'{
    "name": "SEV0815 Kundentyp-Rabatt",
        "priority": 3,
        "obsolete": 0,
        "format_version": $format_version,
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
            },
            {
              "type": "container_or",
              "condition": [
                {
                  "type": "vendor",
                  "id": [ 12, 35, 892, 344, 124 ]
                },
                {
                  "type": "partsgroup",
                  "id": 534
                },
                {
                  "type": "pricegroup",
                  "id": 472
                },
                {
                  "type": "ve",
                  "num": 34.23,
                  "op": "eq"
                },
                {
                  "type": "qty",
                  "num": 827.2,
                  "op": "ge"
                },
                {
                  "type": "qty_range",
                  "min": 1,
                  "max": 10
                },
                {
                  "type": "reqdate",
                  "date_as_epoch": 1259971200,
                  "op": "gt"
                },
                {
                  "type": "transdate",
                  "date_as_epoch": 1259971200,
                  "op": "lt"
                }
              ]
            }
          ]
        },
        "action": {
          "type": "discount_action",
          "discount": 4.00
        }
      }',
  name => 'very complex condition',
  digest => [
    '-4-business-3234-part-815-partsgroup-534-',
    '-4-business-3234-part-815-pricegroup-472-',
    '-4-business-3234-part-815-qtyge--1qtyle--10',
    '-4-business-3234-part-815-qtyge--827.2',
    '-4-business-3234-part-815-reqdategt2009-12-05--',
    '-4-business-3234-part-815-transdatelt2009-12-05--',
    '-4-business-3234-part-815-veeq--34.23',
    '-4-business-3234-part-815-vendor-12-',
    '-4-business-3234-part-815-vendor-124-',
    '-4-business-3234-part-815-vendor-344-',
    '-4-business-3234-part-815-vendor-35-',
    '-4-business-3234-part-815-vendor-892-',
  ],
},
{ json => qq'
  {
  "name": "SRV0815 Warengruppen -> Kundengruppen",
  "priority": 3,
  "obsolete": 0,
    "type": "customer",
  "format_version": $format_version,
  "condition": {
    "type": "container_or",
    "condition": [
      {
        "type": "partsgroup",
        "id": [ 428, 8437 ]
      }
    ]
  },
  "action": {
    "type": "parts_price_list_action",
    "parts_price_list_action_line": [
      {
        "id": 42,
        "discount": 2.00
      },
      {
        "id": 6345,
        "discount": 3.00
      },
      {
        "id": 2344,
        "discount": 4.00
      }
    ]
  }
  }',
  digest => [
    '-2-part-42-partsgroup-428-',
    '-2-part-42-partsgroup-8437-',
    '-3-part-6345-partsgroup-428-',
    '-3-part-6345-partsgroup-8437-',
    '-4-part-2344-partsgroup-428-',
    '-4-part-2344-partsgroup-8437-'
  ],
  name => 'condition + parts price list',
},
{ json => qq'
  {
  "name": "SRV0815 Warengruppen -> Kundengruppen",
  "priority": 3,
  "obsolete": 0,
    "type": "customer",
  "format_version": $format_version,
  "action": {
    "type": "list_template_action",
    "condition_type": "part",
    "action_type": [ "discount" ],
    "list_template_action_line": [
      {
        "id": 42,
        "discount": 2.00
      },
      {
        "id": 6345,
        "discount": 3.00
      },
      {
        "id": 2344,
        "discount": 4.00
      }
    ]
  }
  }',
  digest => [
    '-2-part-42-',
    '-3-part-6345-',
    '-4-part-2344-',
  ],
  name => 'list template: part + discount',
},
{ json => qq'
  {
  "name": "SEV0815 Kundentyp-Rabatt",
  "priority": 3,
  "obsolete": 0,
  "format_version": $format_version,
    "type": "vendor",
  "action": {
    "type": "list_template_action",
    "condition_type": "qty",
    "action_type": [ "price" ],
    "list_template_action_line": [
        {
          "min": 0.00,
          "price": 1100.00
        },
        {
          "min": 10.00,
          "price": 1000.00
        },
        {
          "min": 100,
          "price": 900.00
        }
      ]
    }
  }',
  digest => [
     '1000--qtyge--10qtylt--100',
     '1100--qtyge--0qtylt--10',
     '900--qtyge--100'
  ],
  name => 'list template: qty + price',
},
);

$::request->type('json');
open my $stdout_fh, '>', \my $stdout or die;


for my $case (@test_cases) {
  my $m = SL::DB::PriceRuleMacro->new(json_definition => $case->{json});

  if ($case->{dies_ok}) {
    throws_ok { $m->validate } $case->{dies_ok}, "$case->{name}: expect exeption";
  } else {
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

      if ($case->{form}) {
        SL::Request::_store_value($::form, $_, $case->{$_}) for keys %{ $case->{form} };
      }

      my $result;
      eval {
        my $json_result = $c->action_save;
        $result         = SL::JSON::from_json("$json_result");
        ok $result->{id}, "$case->{name}: save (got id: $result->{id})";
        diag("error: $json_result") unless $result->{id};
        1;
      } or do {
        ok 0, "$case->{name} - exception: $@";
      };

      $m = SL::DB::PriceRuleMacro->new(id => $result->{id})->load;

      isa_ok $m, 'SL::DB::PriceRuleMacro', "$case->{name}: load";

      cmp_deeply [ map { $_->digest } $m->parsed_definition->price_rules ], bag(@{ $case->{digest} }), "$case->{name}: digests still match";
    }
  }
}

done_testing();
