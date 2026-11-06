-- Oracle Loan Package: tables
-- Run this first (APEX: SQL Workshop > SQL Scripts).

create table loans (
  loan_id        number generated always as identity primary key,
  customer_name  varchar2(100) not null,
  principal      number(14,2)  not null check (principal > 0),
  annual_rate    number(5,2)   not null check (annual_rate >= 0),
  term_months    number(4)     not null check (term_months between 1 and 360),
  start_date     date default trunc(sysdate) not null,
  created_on     date default sysdate not null
);

create table loan_schedule (
  loan_id        number not null references loans (loan_id) on delete cascade,
  installment_no number(4) not null,
  due_date       date not null,
  payment        number(14,2) not null,
  interest_part  number(14,2) not null,
  principal_part number(14,2) not null,
  balance        number(14,2) not null,
  constraint loan_schedule_pk primary key (loan_id, installment_no)
);

create table error_log (
  log_id    number generated always as identity primary key,
  logged_at timestamp default systimestamp not null,
  source    varchar2(100),
  message   varchar2(4000)
);

create table test_results (
  run_at    timestamp default systimestamp,
  test_name varchar2(100),
  result    varchar2(10),
  details   varchar2(500)
);
