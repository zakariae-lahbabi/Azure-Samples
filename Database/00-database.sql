
if schema_id('api') is null begin
	exec('create schema api authorization dbo');
end
go

drop sequence if exists dbo.cart_id_generator;
create sequence dbo.cart_id_generator
as bigint start with 1 increment by 1;
go

drop table if exists dbo.shopping_cart;
create table dbo.shopping_cart
(
	[row_id] int identity not null primary key,
	[cart_id] bigint not null,
	[user_id] int not null,
	[item_id] int not null,
	[quantity] int not null,
	[price] decimal (10,4) not null,
	[item_details] nvarchar(max) not null check (isjson(item_details) = 1),
	[added_on] datetime2 not null
)
go

create or alter procedure api.put_shopping_cart
@payload nvarchar(max)
as
set nocount on;
declare @cart_id bigint = next value for dbo.cart_id_generator;
insert into dbo.shopping_cart
	([cart_id], [user_id], [item_id], [quantity], [price], [item_details], [added_on])
select 
	@cart_id,
	c.[user_id], 
	i.[item_id],
	i.[quantity],
	i.[price],
	i.[item_details],
	sysdatetime()
from 
	openjson(@payload) with	(
		[user_id] int, 
		[items] nvarchar(max) as json
	) as c
cross apply
	openjson(c.[items]) with (
		[item_id] int '$.id',
		[quantity] int,
		[price] decimal(10,4),
		[item_details] nvarchar(max) '$.details' as json 
	) as i
go

create or alter procedure api.get_shopping_cart
@cart_id bigint
as
set nocount on;
select top (1)
	c.cart_id,
	c.[user_id],
	json_query((
		select
			item_id as 'id',
			quantity,
			price,
			json_query(item_details) as 'details'
		from
			dbo.shopping_cart as items
		where
			items.cart_id = c.cart_id
		for json path
	)) as items
from 
	dbo.shopping_cart c
where
	cart_id = @cart_id
for json auto, without_array_wrapper
go