-- Oracle Loan Package: body (implementation)

create or replace package body loan_pkg as

  -- private: writes to the log in its own transaction, so it survives a rollback
  procedure log_error(p_source in varchar2, p_message in varchar2) is
    pragma autonomous_transaction;
  begin
    insert into error_log (source, message)
    values (p_source, substr(p_message, 1, 4000));
    commit;
  end log_error;

  function calc_payment(p_principal number, p_annual_rate number, p_months number)
    return number is
    l_r number;
  begin
    if p_principal is null or p_principal <= 0
       or p_annual_rate is null or p_annual_rate < 0
       or p_months is null or p_months < 1 then
      raise_application_error(c_err_bad_input, 'Invalid loan parameters.');
    end if;

    if p_annual_rate = 0 then
      return round(p_principal / p_months, 2);
    end if;

    l_r := p_annual_rate / 100 / 12;   -- monthly interest rate
    return round(p_principal * l_r / (1 - power(1 + l_r, -p_months)), 2);
  end calc_payment;

  procedure generate_schedule(p_loan_id in number) is
    l_loan     loans%rowtype;
    l_payment  number;
    l_balance  number;
    l_interest number;
    l_princ    number;
  begin
    begin
      select * into l_loan from loans where loan_id = p_loan_id;
    exception
      when no_data_found then
        raise_application_error(c_err_not_found, 'Loan ' || p_loan_id || ' not found.');
    end;

    delete from loan_schedule where loan_id = p_loan_id;

    l_payment := calc_payment(l_loan.principal, l_loan.annual_rate, l_loan.term_months);
    l_balance := l_loan.principal;

    for i in 1 .. l_loan.term_months loop
      l_interest := round(l_balance * l_loan.annual_rate / 100 / 12, 2);

      if i = l_loan.term_months then
        l_princ := l_balance;                  -- last installment clears any rounding leftover
      else
        l_princ := l_payment - l_interest;
      end if;

      l_balance := l_balance - l_princ;

      insert into loan_schedule
        (loan_id, installment_no, due_date, payment, interest_part, principal_part, balance)
      values
        (p_loan_id, i, add_months(l_loan.start_date, i),
         l_princ + l_interest, l_interest, l_princ, l_balance);
    end loop;
  exception
    when others then
      log_error('GENERATE_SCHEDULE', sqlerrm);
      raise;
  end generate_schedule;

  procedure create_loan(
    p_customer_name in  varchar2,
    p_principal     in  number,
    p_annual_rate   in  number,
    p_term_months   in  number,
    p_start_date    in  date default trunc(sysdate),
    p_loan_id       out number) is
    l_check number;
  begin
    if p_customer_name is null then
      raise_application_error(c_err_bad_input, 'Customer name is required.');
    end if;

    l_check := calc_payment(p_principal, p_annual_rate, p_term_months);  -- validates the numbers

    insert into loans (customer_name, principal, annual_rate, term_months, start_date)
    values (p_customer_name, p_principal, p_annual_rate, p_term_months, p_start_date)
    returning loan_id into p_loan_id;

    generate_schedule(p_loan_id);
  exception
    when others then
      log_error('CREATE_LOAN', sqlerrm);
      raise;
  end create_loan;

  function outstanding_balance(p_loan_id in number, p_as_of in date default trunc(sysdate))
    return number is
    l_principal loans.principal%type;
    l_last      number;
    l_balance   number;
  begin
    begin
      select principal into l_principal from loans where loan_id = p_loan_id;
    exception
      when no_data_found then
        raise_application_error(c_err_not_found, 'Loan ' || p_loan_id || ' not found.');
    end;

    select max(installment_no) into l_last
      from loan_schedule
     where loan_id = p_loan_id and due_date <= p_as_of;

    if l_last is null then
      return l_principal;                      -- nothing due yet
    end if;

    select balance into l_balance
      from loan_schedule
     where loan_id = p_loan_id and installment_no = l_last;

    return l_balance;
  end outstanding_balance;

end loan_pkg;
/
