COPY custom_variable_configs (id, name, description, type, module, default_value, options, searchable, includeable, included_by_default, sortkey, itime, mtime, flags) FROM stdin;
1   Testvar Ein Test    text    CT          f   f   f   1   2009-05-26 15:39:20.45002   \N  \N
6   ICAO_LDG    DEST    text    IC          t   t   f   4   2009-07-02 20:58:55.844121  2009-07-06 15:38:48.508868  editable=1
3   DEP DEP text    IC  Startort        t   t   f   3   2009-06-30 15:39:34.078988  2009-07-06 15:38:53.161427  editable=1
7   bool    bool    bool    CT  1       t   t   f   6   2009-07-05 19:05:08.463692  \N
16  INDEX   Index   text    IC          t   t   f   2   2009-07-06 15:38:23.081605  2009-07-06 15:38:53.161427  editable=1
14  PILOT   Pilot   text    IC          t   t   f   5   2009-07-06 14:22:03.488833  2009-07-06 15:46:31.835116  editable=1
4   PILOT2  2.Pilot text    IC          t   t   f   7   2009-07-02 20:58:18.262238  2009-07-06 15:46:41.764174  editable=1
5   RULES   Rules   select  IC  IFR IFR##VFR    t   t   f   8   2009-07-02 20:58:34.638175  2009-07-06 18:14:53.256683  editable=1
15  LDG LDG text    IC          t   t   f   15  2009-07-06 15:36:18.309392  2009-07-06 15:38:28.763417  editable=1
13  BLK TFT text    IC          t   t   f   14  2009-07-06 14:21:47.575732  2009-07-06 15:38:30.816017  editable=1
12  TA2 ABT text    IC          t   t   f   13  2009-07-06 14:21:33.786458  2009-07-06 15:38:32.480749  editable=1
11  TA1 AOBT    text    IC          t   t   f   12  2009-07-06 14:21:17.440972  2009-07-06 15:38:34.237022  editable=1
10  FT  TTA text    IC          t   t   f   11  2009-07-06 14:21:01.253932  2009-07-06 15:38:35.828773  editable=1
9   LA  ATA text    IC          t   t   f   10  2009-07-06 14:20:45.866457  2009-07-06 15:38:38.069121  editable=1
8   TO  ATD text    IC          t   t   f   9   2009-07-06 14:20:31.601538  2009-07-06 15:38:40.393254  editable=1
\.

