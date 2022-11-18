-- @tag: chart_add_columns_lohnbuchhaltung_skr03
-- @description: Tabelle chart um Lohnbuchungskonten erweitern
-- @depends: release_3_7_0
-- @ignore: 1

DO $$
BEGIN
  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR03EU' THEN
    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1759 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                                                , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1759' , 'Voraussichtliche Beitragsschuld gegenüber den Sozialversicherungsträgern' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 4190 ) = 0 THEN
        INSERT INTO chart
        (accno  , description     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('4190' , 'Aushilfslöhne' , 'A'       , 'E'      , NULL , 0         , 10        , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1742 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                            , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1742' , 'Verbindlichkeiten im Rahmen der sozialen Sicherheit ' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1741 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1741' , 'Verbindlichkeiten aus Lohn- und Kirchensteuer' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1755 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1755' , 'Lohn- und Gehaltsverrechnung ' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1520 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                                           , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1520' , 'Forderungen gegenüber Krankenkassen aus Aufwendungsausgleichsgesetz' , 'A'       , 'A'      , NULL , 0         , NULL      , NULL    , NULL       , NULL    , FALSE);
      END IF;
    END;
  END IF;

  IF ( SELECT coa FROM defaults ) = 'Germany-DATEV-SKR04EU' THEN
    BEGIN
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 3759 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                                                , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('3759' , 'Voraussichtliche Beitragsschuld gegenüber den Sozialversicherungsträgern' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 6030 ) = 0 THEN
        INSERT INTO chart
        (accno  , description     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('6030' , 'Aushilfslöhne' , 'A'       , 'E'      , NULL , 0         , 10        , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 3740 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                            , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('3740' , 'Verbindlichkeiten im Rahmen der sozialen Sicherheit ' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 3730 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('3730' , 'Verbindlichkeiten aus Lohn- und Kirchensteuer' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 3790 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                     , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('3790' , 'Lohn- und Gehaltsverrechnung ' , 'A'       , 'L'      , 'AP' , 0         , NULL      , NULL    , NULL       , 9       , FALSE);
      END IF;
      IF ( SELECT COUNT(accno) FROM chart WHERE accno LIKE 1369 ) = 0 THEN
        INSERT INTO chart
        (accno  , description                                                           , charttype , category , link , taxkey_id , pos_ustva , pos_bwa , pos_bilanz , pos_eur , datevautomatik) VALUES
        ('1369' , 'Forderungen gegenüber Krankenkassen aus Aufwendungsausgleichsgesetz' , 'A'       , 'A'      , NULL , 0         , NULL      , NULL    , NULL       , NULL    , FALSE);
      END IF;
    END;
  END IF;

END $$

