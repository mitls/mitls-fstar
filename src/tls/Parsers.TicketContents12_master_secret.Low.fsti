module Parsers.TicketContents12_master_secret.Low
include Parsers.TicketContents12_master_secret

module LP = LowParse.Low.Base

val write_ticketContents12_master_secret : LP.leaf_writer_strong ticketContents12_master_secret_serializer
