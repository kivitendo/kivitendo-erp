-- @tag: emmvee_background_jobs
-- @description: Tabellen für Hintergrundjobs
-- @depends: release_2_6_1

CREATE TABLE background_jobs (
    id serial NOT NULL,
    type character varying(255),
    package_name character varying(255),
    last_run_at timestamp without time zone,
    next_run_at timestamp without time zone,
    data text,
    active boolean,
    cron_spec character varying(255),

    PRIMARY KEY (id)
);

CREATE TABLE background_job_histories (
    id serial NOT NULL,
    package_name character varying(255),
    run_at timestamp without time zone,
    status character varying(255),
    result text,
    error text,
    data text,

    PRIMARY KEY (id)
);
