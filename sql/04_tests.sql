-- Oracle Loan Package: automated checks
-- Each check records PASS or FAIL in TEST_RESULTS.
-- View the results with:
--   select test_name, result, details from test_results order by run_at;

declare
  l_id     number;
  l_cnt    number;
  l_sum    number;
  l_bal    number;
  l_val    number;
  l_code   number;
  l_msg    varchar2(500);
  l_before number;

  procedure check_it(p_name in varchar2, p_ok in boolean, p_details in varchar2 default null) is
    l_res varchar2(4);
  begin
    if p_ok then l_res := 'PASS'; else l_res := 'FAIL'; end if;
    insert into test_results (test_name, result, details)
    values (p_name, l_res, substr(p_details, 1, 500));
  end check_it;
begin
  delete from test_results;

  -- payment formula
  check_it('payment 12,000,000 at 12% over 12 months',
           loan_pkg.calc_payment(12000000, 12, 12) = 1066185.46);
  check_it('payment 5,000,000 at 9.5% over 6 months',
           loan_pkg.calc_payment(5000000, 9.5, 6) = 856575.34);
  check_it('payment with zero interest',
           loan_pkg.calc_payment(1200000, 0, 12) = 100000);

  -- bad input is rejected
  begin
    l_val := loan_pkg.calc_payment(-1, 10, 12);
    check_it('negative principal is rejected', false, 'no error was raised');
  exception
    when others then
      l_code := sqlcode;
      l_msg  := sqlerrm;
      check_it('negative principal is rejected', l_code = -20101, l_msg);
  end;

  select count(*) into l_before from error_log where source = 'CREATE_LOAN';
  begin
    loan_pkg.create_loan('Bad Loan', -5, 10, 12, date '2026-01-01', l_id);
    check_it('bad input to create_loan is rejected and logged', false, 'no error was raised');
  exception
    when others then
      l_code := sqlcode;
      l_msg  := sqlerrm;
      select count(*) into l_cnt from error_log where source = 'CREATE_LOAN';
      check_it('bad input to create_loan is rejected and logged',
               l_code = -20101 and l_cnt > l_before, l_msg);
  end;

  -- a real loan and its schedule
  loan_pkg.create_loan('Test Customer', 12000000, 12, 12, date '2026-01-01', l_id);

  select count(*), sum(principal_part) into l_cnt, l_sum
    from loan_schedule where loan_id = l_id;
  check_it('schedule has 12 rows', l_cnt = 12);
  check_it('principal parts add up to the loan amount', l_sum = 12000000);

  select balance into l_bal from loan_schedule where loan_id = l_id and installment_no = 12;
  check_it('final balance is zero', l_bal = 0);

  select interest_part into l_val from loan_schedule where loan_id = l_id and installment_no = 1;
  check_it('first month interest is 120,000', l_val = 120000);

  select payment into l_val from loan_schedule where loan_id = l_id and installment_no = 12;
  check_it('last payment absorbs rounding (1,066,185.52)', l_val = 1066185.52);

  -- outstanding balance on different dates
  check_it('balance before the first due date is the full amount',
           loan_pkg.outstanding_balance(l_id, date '2026-01-15') = 12000000);
  check_it('balance on 2026-06-30 (after 5 payments)',
           loan_pkg.outstanding_balance(l_id, date '2026-06-30') = 7173503.23);
  check_it('balance after the last due date is zero',
           loan_pkg.outstanding_balance(l_id, date '2027-01-01') = 0);

  -- unknown loan
  begin
    l_val := loan_pkg.outstanding_balance(-1);
    check_it('unknown loan is rejected', false, 'no error was raised');
  exception
    when others then
      l_code := sqlcode;
      l_msg  := sqlerrm;
      check_it('unknown loan is rejected', l_code = -20102, l_msg);
  end;

  delete from loans where customer_name = 'Test Customer';   -- schedule rows cascade
  commit;
end;
/
