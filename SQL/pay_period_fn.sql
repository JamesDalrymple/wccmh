USE [jd_utility]
GO

ALTER function [dbo].[fn_jd_get_pay_period](@startdate datetime, @enddate datetime)
returns table
as return /* 3/21/17 James */
with pp_data as
(
select
	@startdate + cast(cast('1/8/2017' as datetime) - 
		@startdate as int) % 14 - 14 as pay_start,
	@startdate + cast(cast('1/8/2017' as datetime) - 
		@startdate as int) % 14 - 1 as pay_end
UNION ALL
select
	pay_start + 14 as pay_start,
	pay_end +  14 as pay_end
FROM pp_data
WHERE pay_start +  14 <= @enddate
)
select 
	pay_start, pay_end,
	case when pay_start < @startdate then @startdate else pay_start end as adj_pay_start, 
	case when pay_end > @enddate then @enddate else pay_end end as adj_pay_end, 
	@startdate as start_dt, @enddate as end_dt,
	cast(case when pay_end > @enddate then @enddate else pay_end end - 
		case when pay_start < @startdate then @startdate else pay_start end + 1
		as int) as adj_calendar_days
where cast(case when pay_end > @enddate then @enddate else pay_end end - 
		case when pay_start < @startdate then @startdate else pay_start end + 1
		as int) > 0
	and pay_end between @startdate and @enddate
from pp_data
