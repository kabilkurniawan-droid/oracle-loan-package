-- Oracle Loan Package: specification (public interface)

create or replace package loan_pkg as
  c_err_bad_input constant pls_integer := -20101;
  c_err_not_found constant pls_integer := -20102;

  function calc_payment(p_principal number, p_annual_rate number, p_months number)
    return number;

  procedure create_loan(
    p_customer_name in  varchar2,
    p_principal     in  number,
    p_annual_rate   in  number,
    p_term_months   in  number,
    p_start_date    in  date default trunc(sysdate),
    p_loan_id       out number);

  procedure generate_schedule(p_loan_id in number);

  function outstanding_balance(p_loan_id in number, p_as_of in date default trunc(sysdate))
    return number;
end loan_pkg;
/
