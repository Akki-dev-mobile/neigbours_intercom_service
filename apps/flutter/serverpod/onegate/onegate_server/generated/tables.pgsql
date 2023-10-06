--
-- Class MemberStaffCategories as table member_staff_categories
--

CREATE TABLE "member_staff_categories" (
  "id" serial,
  "name" text NOT NULL
);

ALTER TABLE ONLY "member_staff_categories"
  ADD CONSTRAINT member_staff_categories_pkey PRIMARY KEY (id);


--
-- Class MemberStaffSubCategories as table member_staff_sub_categories
--

CREATE TABLE "member_staff_sub_categories" (
  "id" serial,
  "name" text NOT NULL,
  "category_id" integer NOT NULL
);

ALTER TABLE ONLY "member_staff_sub_categories"
  ADD CONSTRAINT member_staff_sub_categories_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "member_staff_sub_categories"
  ADD CONSTRAINT member_staff_sub_categories_fk_0
    FOREIGN KEY("category_id")
      REFERENCES member_staff_categories(id)
        ON DELETE CASCADE;

--
-- Class MemberStaff as table member_staff
--

CREATE TABLE "member_staff" (
  "id" serial,
  "name" text NOT NULL,
  "category_id" integer NOT NULL,
  "sub_category_id" integer NOT NULL,
  "company_id" integer NOT NULL,
  "id_proof_type" text NOT NULL,
  "id_proof_number" text NOT NULL,
  "id_proof_image" text NOT NULL
);

ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_fk_0
    FOREIGN KEY("category_id")
      REFERENCES member_staff_categories(id)
        ON DELETE CASCADE;
ALTER TABLE ONLY "member_staff"
  ADD CONSTRAINT member_staff_fk_1
    FOREIGN KEY("sub_category_id")
      REFERENCES member_staff_sub_categories(id)
        ON DELETE CASCADE;

--
-- Class MemberStaffBuildingUnit as table member_staff_building_unit
--

CREATE TABLE "member_staff_building_unit" (
  "id" serial,
  "member_staff_id" integer NOT NULL,
  "building_id" integer NOT NULL,
  "building_unit_id" integer NOT NULL
);

ALTER TABLE ONLY "member_staff_building_unit"
  ADD CONSTRAINT member_staff_building_unit_pkey PRIMARY KEY (id);

ALTER TABLE ONLY "member_staff_building_unit"
  ADD CONSTRAINT member_staff_building_unit_fk_0
    FOREIGN KEY("member_staff_id")
      REFERENCES member_staff(id)
        ON DELETE CASCADE;

