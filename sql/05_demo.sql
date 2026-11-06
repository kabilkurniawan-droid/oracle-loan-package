-- Oracle Loan Package: demo
-- Creates a sample loan (fictional data) and shows its repayment schedule.

declare
  l_id number;
begin
  loan_pkg.create_loan('Demo Customer', 24000000, 10, 24, date '2026-01-01', l_id);
  commit;
end;
/

select installment_no, due_date, payment, interest_part, principal_part, balance
  from loan_schedule
 where loan_id = (select max(loan_id) from loans)
 order by installment_no;
