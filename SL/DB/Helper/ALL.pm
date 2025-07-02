package SL::DB::Helper::ALL;

use strict;

use SL::DB::AccTransaction;
use SL::DB::AdditionalBillingAddress;
use SL::DB::ApGl;
use SL::DB::Assembly;
use SL::DB::AssortmentItem;
use SL::DB::AuthClient;
use SL::DB::AuthClientUser;
use SL::DB::AuthClientGroup;
use SL::DB::AuthGroup;
use SL::DB::AuthGroupRight;
use SL::DB::AuthMasterRight;
use SL::DB::AuthSchemaInfo;
use SL::DB::AuthSession;
use SL::DB::AuthSessionContent;
use SL::DB::AuthUser;
use SL::DB::AuthUserConfig;
use SL::DB::AuthUserGroup;
use SL::DB::BackgroundJob;
use SL::DB::BackgroundJobHistory;
use SL::DB::BankAccount;
use SL::DB::BankTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Bin;
use SL::DB::Buchungsgruppe;
use SL::DB::Business;
use SL::DB::BusinessModel;
use SL::DB::Chart;
use SL::DB::Contact;
use SL::DB::ContactDepartment;
use SL::DB::ContactTitle;
use SL::DB::CsvImportProfile;
use SL::DB::CsvImportProfileSetting;
use SL::DB::CsvImportReport;
use SL::DB::CsvImportReportRow;
use SL::DB::CsvImportReportStatus;
use SL::DB::Currency;
use SL::DB::CustomDataExportQuery;
use SL::DB::CustomDataExportQueryParameter;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::CustomVariableConfigPartsgroup;
use SL::DB::CustomVariableValidity;
use SL::DB::Customer;
use SL::DB::Datev;
use SL::DB::Default;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::DeliveryTerm;
use SL::DB::Department;
use SL::DB::Draft;
use SL::DB::Dunning;
use SL::DB::DunningConfig;
use SL::DB::EmailImport;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Employee;
use SL::DB::EmployeeProjectInvoices;
use SL::DB::Exchangerate;
use SL::DB::File;
use SL::DB::FileFullText;
use SL::DB::FileVersion;
use SL::DB::Finanzamt;
use SL::DB::FollowUp;
use SL::DB::FollowUpAccess;
use SL::DB::FollowUpCreatedForEmployee;
use SL::DB::FollowUpDone;
use SL::DB::FollowUpLink;
use SL::DB::GLTransaction;
use SL::DB::GenericTranslation;
use SL::DB::Greeting;
use SL::DB::History;
use SL::DB::Inventory;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::Language;
use SL::DB::Letter;
use SL::DB::LetterDraft;
use SL::DB::MakeModel;
use SL::DB::Note;
use SL::DB::Object::Hooks;
use SL::DB::Object;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::OrderStatus;
use SL::DB::OrderVersion;
use SL::DB::Part;
use SL::DB::PartClassification;
use SL::DB::PartCustomerPrice;
use SL::DB::PartsGroup;
use SL::DB::PartsPriceHistory;
use SL::DB::PaymentTerm;
use SL::DB::PeriodicInvoice;
use SL::DB::PeriodicInvoicesConfig;
use SL::DB::PriceFactor;
use SL::DB::Pricegroup;
use SL::DB::Price;
use SL::DB::PriceRule;
use SL::DB::PriceRuleItem;
use SL::DB::Printer;
use SL::DB::Project;
use SL::DB::ProjectParticipant;
use SL::DB::ProjectPhase;
use SL::DB::ProjectPhaseParticipant;
use SL::DB::ProjectRole;
use SL::DB::ProjectStatus;
use SL::DB::ProjectType;
use SL::DB::PurchaseBasketItem;
use SL::DB::PurchaseInvoice;
use SL::DB::Reclamation;
use SL::DB::ReclamationItem;
use SL::DB::ReclamationReason;
use SL::DB::ReconciliationLink;
use SL::DB::RecordLink;
use SL::DB::RecordTemplate;
use SL::DB::RecordTemplateItem;
use SL::DB::RequirementSpecAcceptanceStatus;
use SL::DB::RequirementSpecComplexity;
use SL::DB::RequirementSpecDependency;
use SL::DB::RequirementSpecItem;
use SL::DB::RequirementSpecOrder;
use SL::DB::RequirementSpecPart;
use SL::DB::RequirementSpecPicture;
use SL::DB::RequirementSpecPredefinedText;
use SL::DB::RequirementSpecRisk;
use SL::DB::RequirementSpecStatus;
use SL::DB::RequirementSpecTextBlock;
use SL::DB::RequirementSpecType;
use SL::DB::RequirementSpecVersion;
use SL::DB::RequirementSpec;
use SL::DB::SchemaInfo;
use SL::DB::Secret;
use SL::DB::SepaExport;
use SL::DB::SepaExportItem;
use SL::DB::SepaExportMessageId;
use SL::DB::Shipto;
use SL::DB::Shop;
use SL::DB::ShopImage;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::ShopPart;
use SL::DB::Status;
use SL::DB::Stocktaking;
use SL::DB::Tax;
use SL::DB::TaxKey;
use SL::DB::TaxZone;
use SL::DB::TaxzoneChart;
use SL::DB::TimeRecording;
use SL::DB::TimeRecordingArticle;
use SL::DB::TodoUserConfig;
use SL::DB::TransferType;
use SL::DB::Translation;
use SL::DB::TriggerInformation;
use SL::DB::Unit;
use SL::DB::UnitsLanguage;
use SL::DB::UserPreference;
use SL::DB::VC;
use SL::DB::ValidityToken;
use SL::DB::Vendor;
use SL::DB::Warehouse;

1;

__END__

=pod

=head1 NAME

SL::DB::Helper::ALL: Dependency-only package for all SL::DB::* modules

=head1 SYNOPSIS

  use SL::DB::Helper::ALL;

=head1 DESCRIPTION

This module depends on all modules in SL/DB/*.pm for the convenience
of being able to write a simple \C<use SL::DB::Helper::ALL> and
having everything loaded. This is supposed to be used only in the
kivitendo console. Normal modules should C<use> only the modules they
actually need.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
