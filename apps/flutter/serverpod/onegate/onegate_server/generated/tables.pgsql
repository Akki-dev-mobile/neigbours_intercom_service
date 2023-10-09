--
-- Class PurposeCategory as table purpose_category
--

CREATE TABLE "purpose_category" (
  "id" serial,
  "purpose_category_name" text NOT NULL,
  "purpose_img" text NOT NULL
);

ALTER TABLE ONLY "purpose_category"
  ADD CONSTRAINT purpose_category_pkey PRIMARY KEY (id);


--
-- Class PurposeSubCategory as table purpose_sub_category
--

CREATE TABLE "purpose_sub_category" (
  "id" serial,
  "purpose_category_id" integer NOT NULL,
  "purpose_sub_category_name" text NOT NULL,
  "purpose_img" text NOT NULL
);

ALTER TABLE ONLY "purpose_sub_category"
  ADD CONSTRAINT purpose_sub_category_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "purpose_sub_category"
  ADD CONSTRAINT purpose_sub_category_fk_0
    FOREIGN KEY("purpose_category_id")
      REFERENCES purpose_category(id)
        ON DELETE CASCADE;

--
-- Class StaffCategory as table staff_categories
--

CREATE TABLE "staff_categories" (
  "id" serial,
  "category_name" text NOT NULL
);

ALTER TABLE ONLY "staff_categories"
  ADD CONSTRAINT staff_categories_pkey PRIMARY KEY (id);


--
-- Class StaffSubCategory as table staff_sub_categories
--

CREATE TABLE "staff_sub_categories" (
  "id" serial,
  "staff_category_id" integer NOT NULL,
  "sub_categories_name" text NOT NULL
);

ALTER TABLE ONLY "staff_sub_categories"
  ADD CONSTRAINT staff_sub_categories_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "staff_sub_categories"
  ADD CONSTRAINT staff_sub_categories_fk_0
    FOREIGN KEY("staff_category_id")
      REFERENCES staff_categories(id)
        ON DELETE CASCADE;

--
-- Class MemberStaff as table member_staff
--

CREATE TABLE "member_staff" (
  "id" serial,
  "name" text NOT NULL,
  "mobile" text NOT NULL,
  "id_proof" text NOT NULL,
  "id_proof_number" text NOT NULL,
  "id_proof_image" text NOT NULL,
  "staff_category_id" integer NOT NULL,
  "staff_sub_category_id" integer NOT NULL
);

ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_fk_0
    FOREIGN KEY("staff_category_id")
      REFERENCES staff_categories(id)
        ON DELETE CASCADE;
ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_fk_1
    FOREIGN KEY("staff_sub_category_id")
      REFERENCES staff_sub_categories(id)
        ON DELETE CASCADE;

--
-- Class Visitor as table visitor
--

CREATE TABLE "visitor" (
  "id" serial,
  "name" text NOT NULL,
  "mobile" text NOT NULL,
  "visitor_image" text NOT NULL
);

ALTER TABLE ONLY "visitor"
  ADD CONSTRAINT visitor_pkey PRIMARY KEY (id);


--
-- Class BuildingAssignment as table building_assignment
--

CREATE TABLE "building_assignment" (
  "id" serial,
  "visitor_id" integer,
  "building_id" integer NOT NULL,
  "unit_id" json NOT NULL
);

ALTER TABLE ONLY "building_assignment"
  ADD CONSTRAINT building_assignment_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "building_assignment"
  ADD CONSTRAINT building_assignment_fk_0
    FOREIGN KEY("visitor_id")
      REFERENCES visitor(id)
        ON DELETE CASCADE;

--
-- Class VisitorCard as table visitor_card
--

CREATE TABLE "visitor_card" (
  "id" serial,
  "visitor_card_number" text NOT NULL,
  "visitor_card_is_assigned" boolean NOT NULL
);

ALTER TABLE ONLY "visitor_card"
  ADD CONSTRAINT visitor_card_pkey PRIMARY KEY (id);


--
-- Class VisitorLog as table visitor_log
--

CREATE TABLE "visitor_log" (
  "id" serial,
  "visitor" json NOT NULL,
  "visitor_purpose_category_id" integer NOT NULL,
  "visitor_purpose_sub_category_id" integer NOT NULL,
  "visitor_building_assignment" json NOT NULL,
  "visitor_image" text NOT NULL,
  "visitor_count" integer NOT NULL,
  "visitor_check_in" timestamp without time zone NOT NULL,
  "visitor_check_out" timestamp without time zone NOT NULL,
  "visitor_card_number" text NOT NULL,
  "visitor_card_id" integer NOT NULL,
  "company_id" integer NOT NULL
);

ALTER TABLE ONLY "visitor_log"
  ADD CONSTRAINT visitor_log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "visitor_log"
  ADD CONSTRAINT visitor_log_fk_0
    FOREIGN KEY("visitor_purpose_category_id")
      REFERENCES purpose_category(id)
        ON DELETE CASCADE;
ALTER TABLE ONLY "visitor_log"
  ADD CONSTRAINT visitor_log_fk_1
    FOREIGN KEY("visitor_purpose_sub_category_id")
      REFERENCES purpose_sub_category(id)
        ON DELETE CASCADE;
ALTER TABLE ONLY "visitor_log"
  ADD CONSTRAINT visitor_log_fk_2
    FOREIGN KEY("visitor_card_id")
      REFERENCES visitor_card(id)
        ON DELETE CASCADE;

