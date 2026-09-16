require "test_helper"

class IdxScannerJobTest < ActiveSupport::TestCase
  ROW = { open: 1, high: 2, low: 1, close: 2, volume: 10, opened_at: Time.utc(2026, 9, 15) }.freeze

  # Stub metode kelas lalu kembalikan aslinya. Proyek ini tak memakai mocha dan
  # minitest/mock tak tersedia, jadi pola alias/restore dipakai konsisten (sama
  # dengan stub_method di alert_dispatcher_job_test).
  def stub_class_method(klass, name, impl)
    original = klass.method(name)
    klass.define_singleton_method(name) { |*a, **k| impl.call(*a, **k) }
    yield
  ensure
    klass.define_singleton_method(name) { |*a, **k| original.call(*a, **k) }
  end

  def run_with(universe:, client:)
    stub_class_method(IdxUniverseService, :all, -> { universe }) do
      stub_class_method(YahooFinanceClient, :new, -> { client }) do
        yield
      end
    end
  end

  def client_returning(&block)
    c = Object.new
    c.define_singleton_method(:klines, &block)
    c
  end

  # Rate limit dulu membatalkan fetch DIAM-DIAM dan job tetap "sukses" — rantai
  # harian lalu membuat laporan di atas candle kemarin tanpa satu pun alarm.
  test "rate limit di awal membuat job gagal keras, bukan diam" do
    client = client_returning { |**| raise Http::RetryableError.new("HTTP 429") }

    run_with(universe: %w[AAA.JK BBB.JK CCC.JK], client: client) do
      err = assert_raises(RuntimeError) { IdxScannerJob.new.perform }
      assert_match(/tak lengkap/, err.message)
      assert_match(/rate limit/, err.message)
    end
  end

  test "cakupan penuh lolos dan mengembalikan jumlah simbol terambil" do
    client = client_returning { |**| [ ROW.dup ] }

    run_with(universe: %w[AAA.JK BBB.JK], client: client) do
      assert_equal 2, IdxScannerJob.new.perform
    end
  end

  # Kegagalan sporadis (saham suspend yang Yahoo tak punya) tak boleh menjatuhkan
  # seluruh fetch — hanya cakupan di bawah MIN_COVERAGE yang gagal.
  test "satu simbol gagal dari sepuluh tetap lolos" do
    client = client_returning do |symbol:, **|
      raise "no data" if symbol == "AAA.JK"
      [ ROW.dup ]
    end

    universe = (1..10).map { |i| i == 1 ? "AAA.JK" : "S#{i}.JK" }
    run_with(universe: universe, client: client) do
      assert_equal 9, IdxScannerJob.new.perform
    end
  end

  # Dua dari sepuluh gagal = 80% < MIN_COVERAGE 90% → harus gagal keras.
  test "cakupan di bawah ambang gagal walau tanpa rate limit" do
    client = client_returning do |symbol:, **|
      raise "no data" if %w[AAA.JK BBB.JK].include?(symbol)
      [ ROW.dup ]
    end

    universe = %w[AAA.JK BBB.JK] + (3..10).map { |i| "S#{i}.JK" }
    run_with(universe: universe, client: client) do
      err = assert_raises(RuntimeError) { IdxScannerJob.new.perform }
      assert_match(/80\.0%/, err.message)
      assert_no_match(/rate limit/, err.message)
    end
  end
end
