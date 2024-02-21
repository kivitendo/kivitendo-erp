These tests are for handling of foreign currencies in the old bin/mozilla controllers.

At the time of this writing, the problems are a combination of the following properties:


1. The old controllers accumulate data on each roundtrip, and user intend often gets lost before even saving, especially with:
  - tax included
  - foreign exchange
  - discounts/price
  - payment details

  These information must be processed and rendered both when coming from the user (freshly input) and when coming from the database (when loading a posted invoice)

2. payment specifically has 3 paths that can create them:
  - directly in the bin/mozilla form
  - via bank import
  - with the new Payment helper

3. fx transactions are booked internally in the system currency, but displayed in the frontend in the foreign currency.

4. exchangerates are saved independantly for post date and payment date, which can lead to gains/losses when converting to system currency

   example
     user buys for 1000$ (system currency €, exchangerate 1€ - 2$):
     purchase invoice shows 1000$, but gets posted as 500€
     customer pays 800$, which would be 80% of the invoice, 400€ at the initial exchangerate
     but exchangerate at payment date is now 1€ = 1$, so the payment ist actually 800€
     invoice still gets 400€ paid. the other 400€ get put into losses  from exchangerates


5. a special case arises for invoices with foreign currency where the payment is exchanged by the bank and then imported in default currency into kivitendo:


For a normal purchase invoice with foreign currency:

  1. main transaction (in system currency)
    - -500 chart
    - +500 Verb.a.L.u.L.
  2. payment proportional to stated value in foreign currency converted into system currency: 800$ ist 80% of 1000$, so 80% of 500€ get cleared
    - -400 Verb.a.L.u.L. - payment clears 80% of the total amount
    - +800 Kasse         - the stated amount in dollar, which happens to also be the euro amount
    - -400 fxloss (fx_trasnaction) - the difference is lost

With an exchangerate of 1€ = 1.6$ (500€ = 800$) at payment time, the listing would be:

  1. main transaction (in system currency)
    - -500 chart
    - +500 Verb.a.L.u.L.
  2. payment proportional to stated value in foreign currency converted into system currency: 800$ ist 80% of 1000$, so 80% of 500€ get cleared
    - -400 Verb.a.L.u.L. - payment clears 80% of the total amount
    - +800 Kasse         - the stated amount in dollar
    - -300 Kasse (fx_transaction) - to bring the amount down to the real 500€
    - -100 fxloss        - aghain, the difference is lost

For a bank transaction the payment is instead exchanged _before_ being added into the purchase invoice, so there is no fx_transaction

  1. main transaction (in system currency)
    - -500 chart
    - +500 Verb.a.L.u.L
  2. payment proportional to stated value in foreign currency converted into system currency + fx correction
    - -400 Verb.a.L.u.L.
    - +400 Kasse

in this case there are no fx_transctions.


6. Old controllers now need to display both of these cases as they find them in the database and preserve them through update(), post() and post_payment()



